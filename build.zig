const std = @import("std");

pub fn build(b: *std.Build) void {
    var target = std.Target.Query{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
    };
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    const Features = std.Target.x86.Feature;

    target.cpu_features_sub.addFeature(@intFromEnum(Features.mmx));
    target.cpu_features_sub.addFeature(@intFromEnum(Features.sse));
    target.cpu_features_sub.addFeature(@intFromEnum(Features.sse2));
    target.cpu_features_sub.addFeature(@intFromEnum(Features.avx));
    target.cpu_features_sub.addFeature(@intFromEnum(Features.avx2));

    target.cpu_features_add.addFeature(@intFromEnum(Features.soft_float));

    const krn = b.addExecutable(.{
        .name = "kernel.bin",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(target),
            .link_libc = false,
            .optimize = optimize,
            .stack_check = false,
            .stack_protector = false,
            .single_threaded = true,
            .red_zone = false,
            .sanitize_thread = false,
            .sanitize_c = .off,
        }),
    });

    krn.setLinkerScript(b.path("linker.ld"));
    const krn_install = b.addInstallArtifact(krn, .{
        .dest_dir = .{ .override = .{ .custom = "." } },
    });
    krn_install.step.dependOn(&krn.step);
    b.getInstallStep().dependOn(&krn_install.step);
    const krn_install_path = b.getInstallPath(
        krn_install.dest_dir.?,
        krn_install.dest_sub_path
    );

    // Qemu command
    const qemu_step = b.step("qemu", "Run with qemu");
    const qemu_cmd = b.addSystemCommand(&[_][]const u8{
        "qemu-system-i386",
        "-kernel", krn_install_path,
        "-serial", "stdio",
        "-display", "none",
    });
    qemu_cmd.step.dependOn(b.getInstallStep());
    qemu_step.dependOn(&qemu_cmd.step);

    const dbg_qemu_cmd = b.addSystemCommand(&[_][]const u8{
        "qemu-system-i386",
        "-kernel", krn_install_path,
        "-chardev",
        "socket,id=serial0,path=/tmp/serial.sock,server=on,wait=off",
        "-serial", "chardev:serial0",
        "-display", "none",
        "-daemonize",
        "-s",
        "-S",
    });
    dbg_qemu_cmd.step.dependOn(b.getInstallStep());
    
    // GDB command (qemu + gdb)
    const dbg_step = b.step("gdb", "Run with qemu and gdb");
    const gdb_gdb_cmd = b.addSystemCommand(&[_][]const u8{
        "gdb", krn_install_path,
        "-ex", "target remote localhost:1234",
        "-ex", "layout split src asm",
        "-ex", "b kernel_main",
        "-ex", "c",
    });
    gdb_gdb_cmd.step.dependOn(&dbg_qemu_cmd.step);
    dbg_step.dependOn(&gdb_gdb_cmd.step);

    // LLDB command (qemu + lldb)
    const lldb_step = b.step("lldb", "Run with qemu and glldb");
    const lldb_cmd = b.addSystemCommand(&[_][]const u8{
        "lldb",
        "-o", "settings set target.x86-disassembly-flavor intel",
        "-o", "break set -n kernel_main",
        "-o", "gdb-remote localhost:1234",
        "-o", "continue",
        "--", krn_install_path
    });
    lldb_cmd.step.dependOn(&dbg_qemu_cmd.step);
    lldb_step.dependOn(&lldb_cmd.step);

    // TTY command (socat to connect to qemu serial port)
    const tty_step = b.step("tty", "tty for debug");
    const tty_cmd = b.addSystemCommand(&[_][]const u8{
        "socat",
        "-,raw,echo=0",
        "UNIX-CONNECT:/tmp/serial.sock",
    });
    tty_step.dependOn(&tty_cmd.step);
}
