const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
        .abi = .none,
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
    });
    exe.root_module.strip = true;
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
        "-kernel",
        "kernel-source/arch/arm64/boot/Image",
        "-initrd",
        "zig-out/bin/initramfs.cpio",
        "-device",  "virtio-gpu-pci,edid=on", // edid=on tells the GPU to simulate a monitor's identity
        "-display", "sdl",
        "-vga",    "none", // Ensure it doesn't try to use a standard VGA card instead of virtio
        "-serial", "mon:stdio",
        "-append", "console=ttyAMA0 devtmpfs.mount=1",
    });
    qemu_cmd.step.dependOn(package_step);
    run_step.dependOn(&qemu_cmd.step);
}
