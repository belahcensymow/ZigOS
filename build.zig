const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
        .abi = .musl,
    });

    const optimize = b.standardOptimizeOption(.{});

    const os_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "init",
        .root_module = os_module,
        .linkage = .static,
    });

    exe.linkLibC();

    exe.root_module.addObjectFile(b.path("deps/lib/libdrm-2.4.131/libdrm.a"));
    exe.root_module.addSystemIncludePath(.{ .cwd_relative = "/usr/include/libdrm" });
    exe.root_module.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });

    // exe.root_module.strip = true;
    // exe.root_module.link_libc = true;
    // exe.root_module.addIncludePath(b.path("libdrm/"));
    // exe.root_module.addIncludePath(b.path("libdrm/include/"));
    // exe.root_module.addCSourceFiles(.{
    //     .root = b.path("libdrm"),
    //     .files = &.{
    //         "xf86drm.c",
    //         "xf86drmMode.c",
    //         // Add other necessary .c files here
    //     },
    //     .flags = &.{"-std=gnu11"},
    // });
    // exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/include/libdrm" });
    // exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/include/gnu/" });
    // exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/include" });
    // exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/include/" });
    // exe.root_module.linkSystemLibrary("libdrm", .{ .preferred_link_mode = .static });

    b.installArtifact(exe);

    const package_step = b.step("package", "Create the initramfs archive");

    const cpio_cmd = b.addSystemCommand(&.{
        "sh",                                                             "-c",
        "cd zig-out/bin && echo init | cpio -o -H newc > initramfs.cpio",
    });

    cpio_cmd.step.dependOn(b.getInstallStep());
    package_step.dependOn(&cpio_cmd.step);

    const run_step = b.step("qemu", "Run the OS in QEMU-ARM64");

    const qemu_cmd = b.addSystemCommand(&.{
        "qemu-system-aarch64",
        "-M",
        "virt",
        "-cpu",
        "cortex-a76",
        "-m",
        "2G",
        "-object",
        "memory-backend-memfd,id=mem1,size=2G,share=on",
        "-machine",
        "virt,memory-backend=mem1,secure=off",
        "-kernel",
        "kernel-source/arch/arm64/boot/Image",
        "-initrd",
        "zig-out/bin/initramfs.cpio",
        "-device",
        "virtio-gpu-pci,edid=on,blob=on,xres=1280,yres=800",
        "-display",
        "gtk,gl=on",
        "-vga",
        "none",
        "-serial",
        "mon:stdio",
        "-append",
        "console=ttyAMA0,devtmpfs.mount=1,initcall_blacklist=virtio_gpu_init",
    });
    qemu_cmd.step.dependOn(package_step);
    run_step.dependOn(&qemu_cmd.step);
}
