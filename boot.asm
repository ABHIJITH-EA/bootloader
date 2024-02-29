/*
    Boot.s
    The BIOS will put this bootloader at location "0x7c00"
    From there we will start our work on tweaking the Intel x86 H/W.

    - First thing that we have to do is make the assembler to generate 16 bit code
      because the BIOS going to put as in a tiny world of 16 bit registers the "real mode"
 */
BOOT_SIGNATURE = 0xAA55
A20_TEST_VALUE = 0x8978

ES_EDGE_ADDR   = 0xF800
ES_OFFSET_ADDR = 0x8000

.code16
.global start
start:
    cli
    cld
    xorw %ax, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss
    movw $0x7C00, %sp



/*
    Interrupts
    ----------
    - IA-32 Architecture defines 18 predefined and 224 user defined interrupts
      0x0 - 0x8, 0xA - 0xE, 0x10 - 0x13 are H/W interrupts and 0x20 - 0xFF are S/W
      interrupts.
    - Generally interrupts 0x20 - 0x3F are used by BIOS
 */

/*
     Enable A20 Gate

     IC 8042: PS/2 keyboard controller used in IBM PC AT (x86 system's)
     I/O ports:
              [*]0x64 -> command/status port
                         reading from the port gets status from the controller
                         writing to the port sends commands to the controller

              [*]0x60 -> Output buffer port.
                         reading from the port gets data from the controller

              [*]0x60 -> Input buffer port.
                         writing to the port sends data to the controller

     Output buffer: 8 bit read only register at address 0x60
     Input buffer : 8 bit write only register at 0x60
                    When data written the bit 1 of status register set to 1 (input-buffer-full)
                    Writing data to this buffer through the port 0x64 considered as command.
                    Paramaters of the keyboard commands send to the buffer through port 0x60.

     Input port bytes:
              [*] 7-2 -> Reserved
              [*] 1   -> Auxilary data in
              [*] 0   -> Auxilary data out
     Output port bytes:
              [*] 7 -> Keyboard data out
              [*] 6 -> keyboard clock out
              [*] 5 -> IRQ12
              [*] 4 -> IRQ01
              [*] 3 -> Auxiliary clock out
              [*] 2 -> Auxiliary data out
              [*] 1 -> Gate address line 20
              [*] 0 -> Reset microprocessor

     Importand commands:
              [*]D0 -> Read the output port and place it in output buffer.
                       use only if output buffer empty.
              [*]D1 -> Data written to the input buffer will be placed in output port.


     Note: Data should be written to input buffer only if data buffer is
           empty (status register bit 1 -> 0).

     Enable A20 Line
     --------------
     * set bit 1 of output port
     * set bit 1 of port 0x92

 */

movw $0x2402, %ax
int $0x15

movw $0x2400, %ax
int $0x15

movw $0x2402, %ax
int $0x15
call check_a20_status
jmp .

/*
    Check A20 line status
    ---------------------
    Note: 1MB is the maximux address range possible for 16-bit microporcessor (8086).
    This is an example for the a segmeneted address in real mode "0xf800:0x7ff". Trying to increment
    the offset of this address will cause a wrap around to physical address (0x00000000).
    But in CPU's with more than 1MB of address range(80286 24-bit address bus) that increment will
    corresponds to a physical address "0x00100000".

    We will take advantage of this to check A20 line is enabled or not.

 */

/*
    Operand addressing
    ------------------------
    - The operator ":" is used for segment overriding
      eg: mov ES:[EBX], EAX
    - The offset part can be specified as displacement(direct value) or computed through
      effective address.
      `
         EA = Base + (Index * Scale) + Displacement
      `
         * Displacement can be 8, 16, or 32 - bit value
         * Index, and Base values are specified in general purpose register
         * Scale factor can be value of 2, 4, or 8.

         * ESP register can't be used as an index register
         * If ESP or EBP are used as base register then the segment is default to SS
           In all other cases it segment default to DS.

         * any of these component can be NULL


      AT&T Syntax=> Segment:disp(base, index, scale)
 */

check_a20_status:
    xorw %ax, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %cx
    movw $ES_EDGE_ADDR, %ax
    movw $ES_OFFSET_ADDR, %bx
    movw %ax, %es
    movw $A20_TEST_VALUE, %es:(%bx)
    movw %ds:0x0, %ax

    ret
/*
    Setting up a stack
    -----------------
    - After a POWER ON/RESETthe CPU start from 0xFFFF0 and BIOS will put the bootloader at
      physical address 0x07C00. First 512 bytes of the LOW Memory will be our bootloader code
      so we can only setup the stack segment after this address or we will override the bootloader

 */

signature_padding:
    .space 510 - (. - start)
    .word  BOOT_SIGNATURE
