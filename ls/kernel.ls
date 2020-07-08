OUTPUT_FORMAT("binary");
KERNEL_BASE = 0x0;

SECTIONS {
	. = KERNEL_BASE;
	.text : {*(.text)}
	.data : {*(.data)}
}

