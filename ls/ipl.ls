OUTPUT_FORMAT("binary");
IPL_BASE = 0x0;

SECTIONS {
	. = IPL_BASE;
	.text : {*(.text)}
	.data : {*(.data)}
	. = IPL_BASE + 0x1f6;
	.sign : {
		LONG(0x00000001); LONG(0x00000001);
		SHORT(0xaa55);
	}
}

