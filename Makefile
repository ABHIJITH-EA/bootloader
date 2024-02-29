CC = gcc
CFLAGS = -nostartfiles -nostdlib -m32 -e start -g
LFLAGS = -Wl,-Ttext=0x7c00 -Wl,--build-id=none -Wl,--oformat=binary
BOOT_BIN = -o boot.bin
BOOT_SRC = boot.S
GDB_PORT=3773

obj:
	gcc -nostartfiles -nostdlib -m32 -e start -g -Wl,-Ttext=0x7c00 -o boot.out boot.S

objdump: obj
	objdump -mi8086 -d boot.out

image: obj
	$(CC) $(CFLAGS) $(LFLAGS) $(BOOT_BIN) $(BOOT_SRC)

qemu: image
	qemu-system-i386 -drive file=boot.bin,format=raw

debug: image
	qemu-system-i386 -drive file=boot.bin,format=raw -nographic -serial mon:stdio -gdb tcp::$(GDB_PORT) -S

gdb:
	gdb -n -x .gdbinit

clean:
	rm -rf *.bin *.out
