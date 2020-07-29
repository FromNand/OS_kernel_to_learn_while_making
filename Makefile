ARG=

ASM=./asm
OBJ=./obj
LS =./ls

IMG=OS.img

disass:
	@ndisasm -b 16 $(ARG) | less

$(IMG): $(ASM)/ipl.s $(ASM)/kernel.s
	@gcc -nostdlib -T$(LS)/ipl.ls $(ASM)/ipl.s -o $(OBJ)/ipl.bin
	@gcc -nostdlib -T$(LS)/kernel.ls $(ASM)/kernel.s -o $(OBJ)/kernel.bin
	@cat $(OBJ)/ipl.bin $(OBJ)/kernel.bin > $(IMG)

img: $(IMG)

burn: $(IMG)
	@sudo dd if=$? of=/dev/sdb

# layout regs, layout srcも使いやすそう
debug: $(IMG)
	@qemu-system-i386 -S -s -m 32 -localtime -drive file=$?,format=raw &
	@gdb -q \
	-ex 'target remote localhost:1234' \
	-ex 'set architecture i8086' \
	-ex 'set tdesc filename target.xml' \
	-ex 'break *0x7c00' \
	-ex 'continue' \
#	-ex 'layout asm'

# 「-monitor stdio」を取り除いて、「ctrl + alt + 2」をqemuウィンドウで押すことでもQEMUモニタが使える。
monitor: $(IMG)
	@qemu-system-i386 -L . -m 32 -localtime -monitor stdio -vga std -drive file=$?,format=raw

run: $(IMG)
	@qemu-system-i386 -L . -m 32 -localtime -vga std -drive file=$?,format=raw

clean:
	@rm -f $(OBJ)/*
	@rm -f OS.img
