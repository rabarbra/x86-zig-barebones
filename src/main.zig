const std = @import("std");

const MULTIBOOT_MAGIC: u32 = 0x1BADB002;
const MULTIBOOT_FLAGS: u32 = 0x00000003;
const MULTIBOOT_CHECKSUM: u32 = 0 -% (MULTIBOOT_MAGIC + MULTIBOOT_FLAGS);

pub export const multiboot_hdr align(4) linksection(".multiboot") = [_]u32{
    MULTIBOOT_MAGIC,
    MULTIBOOT_FLAGS,
    MULTIBOOT_CHECKSUM,
};

const stack_size: u32 = 16 * 1024;
var boot_stack: [stack_size]u8 align(16) = undefined;

export fn _start() callconv(.naked) noreturn {
    const stack_top = @as(u32, @intFromPtr(&boot_stack)) + stack_size;
    const top_aligned = (stack_top & ~@as(u32, 0xF)) + 4;
    asm volatile (
        \\ cli
        \\ cld
        \\ mov %[stack], %esp
        \\ xor %ebp, %ebp
        \\ call kernel_main
        \\ hlt
        \\
        :
        : [stack] "{esp}" (top_aligned),
    );
    while (true) {}
}

export fn kernel_main() noreturn {
    serial_init();
    puts(
        \\Zig barebones x86 kernel started
        \\    _   _                 
        \\   (_) (__    __   o  _   
        \\\) (_)  \_)     )  ( (_(  
        \\(\             (__     _) 
        \\============================
        \\
    );
    eval_loop();
}

const COM1: u16 = 0x3F8;

pub inline fn outw(port: u16, value: u16) void {
    asm volatile (
        "outw %[value], %[port]"
        :
        : [value] "{ax}" (value),
          [port] "{dx}" (port),
        : .{ .memory = true }
    );
}

pub inline fn outb(port: u16, val: u8) void {
    asm volatile (
        "outb %[value], %[port]"
        :
        : [value] "{al}" (val),
          [port] "{dx}" (port),
        : .{ .memory = true }
    );
}

pub inline fn inb(port: u16) u8 {
    return asm volatile (
        "inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "{dx}" (port),
        : .{ .memory = true }
    );
}

fn serial_init() void {
    outb(COM1 + 1, 0x00);
    outb(COM1 + 3, 0x80);
    outb(COM1 + 0, 0x03);
    outb(COM1 + 1, 0x00);
    outb(COM1 + 3, 0x03);
    outb(COM1 + 2, 0xC7);
    outb(COM1 + 4, 0x0B);

    outb(COM1 + 4, 0x1E);
    outb(COM1 + 0, 0xAE);
    if (inb(COM1 + 0) == 0xAE) {
        outb(COM1 + 4, 0x0F);
        puts("Serial port initialized.\r\n");
    } else {
        outb(COM1 + 4, 0x0F);
        puts("Serial port initialization failed!\r\n");
    }
}

fn putc(c: u8) void {
    while ((inb(COM1 + 5) & 0x20) == 0) {}
    outb(COM1, c);
}

fn puts(s: []const u8) void {
    for (s) |ch| {
        if (ch == '\n') {
            putc('\r');
        }
        putc(ch);
    }
}

fn getc() u8 {
    while ((inb(COM1 + 5) & 0x01) == 0) {}
    return inb(COM1);
}

pub fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    const res = std.fmt.bufPrint(buf[0..], fmt, args) catch {
        puts("print error\r\n");
        return;
    };
    puts(res);
}

fn handle_input(line: []const u8) void {
    if (std.mem.eql(u8, line, "help")) {
        puts(
            \\  Available commands:
            \\   help: show this message
            \\   panic: cause a kernel panic
            \\   off: power off the machine
            \\
        );
    } else if (std.mem.eql(u8, line, "panic")) {
        var a: usize = 1;
        a -= 1;
        _ = 42 / a;
    } else if (std.mem.eql(u8, line, "off")) {
        _ = outw(0x604, 0x2000);
    } else {
        print(
            \\  {s}: unrecognized command.
            \\  input "help" for available commands.
            \\
            , .{line}
        );
    }
}

var input_line: [128]u8 = .{0} ** 128;

fn eval_loop() noreturn {
    var idx: usize = 0;
    puts("> ");
    while (true) {
        const c = getc();
        if (c == '\r' or c == '\n') {
            puts("\r\n");
            if (idx > 0) {
                handle_input(input_line[0..idx]);
            }
            idx = 0;
            puts("> ");
        } else {
            putc(c);
            input_line[idx] = c;
            idx += 1;
            if (idx >= input_line.len) {
                idx = 0;
            }
        }
    }
}

pub fn panic(
    msg: []const u8,
    _: ?*std.builtin.StackTrace,
    _: ?usize
) noreturn {
    puts("Kernel panic!\r\n");
    puts(msg);
    puts("\r\n");
    while (true) {}
}
