const std = @import("std");
const os = std.os.linux;
const c = @cImport({
    @cDefine("_GNU_SOURCE", "1");
    @cInclude("xf86drm.h");
    @cInclude("xf86drmMode.h");
    @cInclude("stdio.h");
});

pub fn main() !void {
    _ = os.mount("devtmpfs", "/dev", "devtmpfs", 0, 0);
    _ = os.mkdirat(os.AT.FDCWD, "/sys", 0o755);
    _ = os.mount("sysfs", "/sys", "sysfs", 0, 0);
    const fd = std.os.linux.open("/dev/dri/card0", .{ .ACCMODE = .RDWR }, 0);
    defer _ = os.close(@intCast(fd));

    if (c.drmSetClientCap(@intCast(fd), c.DRM_CLIENT_CAP_ATOMIC, 1) != 0) {
        std.debug.print("Atomic KMS not supported\n", .{});
        return;
    }

    std.debug.print("Atomic DRM initialized successfully!\n", .{});
    _ = c.printf("hi\n");
}
