const std = @import("std");
const os = std.os.linux;

pub fn main() noreturn {
    const fb_var_screeninfo = extern struct {
        xres: u32,
        yres: u32,
        xres_virtual: u32,
        yres_virtual: u32,
        xoffset: u32,
        yoffset: u32,
        bits_per_pixel: u32,
        grayscale: u32,
        red: [4]u32, // offset, length, msb_right
        green: [4]u32,
        blue: [4]u32,
        transp: [4]u32,
        nonstd: u32,
        activate: u32,
        height: u32,
        width: u32,
        accel_flags: u32,
        pixclock: u32,
        left_margin: u32,
        right_margin: u32,
        upper_margin: u32,
        lower_margin: u32,
        hsync_len: u32,
        vsync_len: u32,
        sync: u32,
        vmode: u32,
        rotate: u32,
        colorspace: u32,
        reserved: [4]u32,
    };

    const FBIOGET_VSCREENINFO: u32 = 0x4600;
    // 1. Setup Filesystem
    _ = os.syscall3(.mkdirat, @bitCast(@as(i64, os.AT.FDCWD)), @intFromPtr("/dev\x00"), 0o755);
    _ = os.syscall5(.mount, @intFromPtr("devtmpfs\x00"), @intFromPtr("/dev\x00"), @intFromPtr("devtmpfs\x00"), 0, 0);

    log("\x1b[32m[NoComp-OS]\x1b[0m Booting Graphics...\n");

    // 2. Open the Framebuffer (The reliable way)
    // We try fb0 first.
    const fb_path = "/dev/fb0\x00";
    const fd = os.syscall3(.openat, @bitCast(@as(i64, os.AT.FDCWD)), @intFromPtr(fb_path.ptr), 2);

    if (fd > 0xFFFFFFFFFFFFF000) {
        log("[NOCOMP] ERROR: /dev/fb0 not found. Check Kernel Config.\n");
        while (true) {}
    }
    var vinfo = std.mem.zeroInit(fb_var_screeninfo, .{});
    _ = os.syscall3(.ioctl, fd, FBIOGET_VSCREENINFO, @intFromPtr(&vinfo));
    // Global or inside main
    const fb_size = vinfo.yres_virtual * vinfo.xres_virtual * (vinfo.bits_per_pixel / 8);

    const fb_ptr_raw = os.syscall6(.mmap, 0, fb_size, 3, 1, fd, 0);
    const pixels: [*]u32 = @ptrFromInt(fb_ptr_raw);

    // FILL BACKGROUND
    for (0..vinfo.yres) |y| {
        for (0..vinfo.xres) |x| {
            // Index = (y * virtual_width) + x
            pixels[y * vinfo.xres_virtual + x] = 0xFF222222;
        }
    }

    // DRAW SQUARE
    const sq_size = 100;
    const center_y = vinfo.yres / 2;
    const center_x = vinfo.xres / 2;

    for (0..sq_size) |y| {
        for (0..sq_size) |x| {
            const py = (center_y - 50) + y;
            const px = (center_x - 50) + x;
            pixels[py * vinfo.xres_virtual + px] = 0xFF00FF00;
        }
    }
    // 1. Try to disable the cursor via TTY ioctl (KDSETMODE)
    const tty_fd = os.syscall3(.openat, @bitCast(@as(i64, os.AT.FDCWD)), @intFromPtr("/dev/tty1\x00"), 2);
    if (tty_fd < 0xFFFFFFFFFFFFF000) {
        // 0x4B3A is KDSETMODE, 0x01 is KD_GRAPHICS (disables console rendering)
        _ = os.syscall3(.ioctl, tty_fd, 0x4B3A, 0x01);
    }

    // 2. Write to the sysfs unbind file (The nuclear option)
    const unbind_path = "/sys/class/vtconsole/vtcon1/bind\x00";
    const unbind_fd = os.syscall3(.openat, @bitCast(@as(i64, os.AT.FDCWD)), @intFromPtr(unbind_path.ptr), 2);
    if (unbind_fd < 0xFFFFFFFFFFFFF000) {
        _ = os.syscall3(.write, unbind_fd, @intFromPtr("0"), 1);
    }
    var back_buffer: [1024 * 768]u32 = undefined;
    const FBIO_WAITFORVSYNC: u32 = 0x40044640;
    var frame: u32 = 0;
    while (true) {
        // 1. Clear Back Buffer (Paint it Grey)
        @memset(&back_buffer, 0xFF222222);

        // 2. Draw Moving Square
        const x_pos = (frame % 800) + 100;
        const y_pos = 300;

        for (0..100) |y| {
            for (0..100) |x| {
                const idx = (y_pos + y) * vinfo.xres_virtual + (x_pos + x);
                back_buffer[idx] = 0xFF00FF00;
            }
        }
        var dummy: u32 = 0;
        _ = os.syscall3(.ioctl, fd, FBIO_WAITFORVSYNC, @intFromPtr(&dummy));
        // 3. FLIP: Copy to Hardware
        // We copy row-by-row to be safe with the virtual stride
        if (vinfo.xres == vinfo.xres_virtual) {
            // The memory is contiguous! Copy the whole thing at once.
            @memcpy(pixels[0 .. fb_size / 4], back_buffer[0 .. fb_size / 4]);
        } else {
            // Keep the row-by-row loop for safety
            for (0..vinfo.yres) |y| {
                const src_row = back_buffer[y * vinfo.xres_virtual .. (y + 1) * vinfo.xres_virtual];
                const dest_ptr = pixels + (y * vinfo.xres_virtual);
                @memcpy(dest_ptr[0..vinfo.xres_virtual], src_row);
            }
        }
        const FBIOPAN_DISPLAY: u32 = 0x4606;

        // This tells the kernel to "flip" the view to the current offset,
        // which forces QEMU/SDL to redraw the screen.
        _ = os.syscall3(.ioctl, fd, FBIOPAN_DISPLAY, @intFromPtr(&vinfo));

        frame += 5;

        // 4. Wait a bit (approx 60fps)
        const ts = os.timespec{ .sec = 0, .nsec = 16_666_667 };
        _ = os.syscall2(.nanosleep, @intFromPtr(&ts), 0);
    }
}

pub fn log(msg: []const u8) void {
    _ = os.syscall3(.write, 1, @intFromPtr(msg.ptr), msg.len);
}
