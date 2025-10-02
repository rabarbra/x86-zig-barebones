ENTRY(_start)

OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)

SECTIONS
{
    . = 0;
    .multiboot : {
        KEEP(*(.multiboot))
    }
    . = 1M;
    .text : ALIGN(16) {
        *(.text .text.*)
    }
    .rodata : ALIGN(16) {
        *(.rodata .rodata.*)
    }
    .data : ALIGN(16) { 
        *(.data .data.*)
    }
    .bss : ALIGN(16) {
        *(.bss .bss.* COMMON)
    }
}
