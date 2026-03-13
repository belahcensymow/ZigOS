const std = @import("std");
const posix = std.posix;
const os = std.os.linux;

// IOCTL Constants
const DRM_IOCTL_SET_MASTER = 0x0000641E;
const DRM_IOCTL_MODE_GETRESOURCES = 0xC04064A0;
const DRM_IOCTL_MODE_GETCONNECTOR = 0xC05064A7;
const DRM_IOCTL_MODE_GETENCODER = 0xC01464A6;
const DRM_IOCTL_MODE_CREATE_DUMB = 0xC02064B2;
const DRM_IOCTL_MODE_ADDFB = 0xC01C64AE;
const DRM_IOCTL_MODE_MAP_DUMB = 0xC01064B3;
const DRM_IOCTL_MODE_SETCRTC = 0xC06864A2;
const DRM_IOCTL_MODE_ATOMIC = 0xC03864BC;
const DRM_IOCTL_MODE_OBJ_GETPROPERTIES = 0xC02064B9;
const DRM_CLIENT_CAP_ATOMIC = 3;
const DRM_IOCTL_SET_CLIENT_CAP = 0x4010640D;
const DRM_IOCTL_MODE_GETPROPERTY = 0xC04064AA;
const DRM_MODE_OBJECT_CRTC = 0xCCCCCCCC;
const DRM_MODE_OBJECT_CONNECTOR = 0xC0C0C0C0;
const DRM_MODE_OBJECT_PLANE = 0xEEEEEEEE; // This is correct, but let's be careful
const DRM_IOCTL_VERSION = 0xC0406400;
const DRM_IOCTL_MODE_GETPLANERESOURCES = 0xC01064B6;
const DRM_IOCTL_MODE_GETPLANE = 0xC02064B7;

// EXACT KERNEL STRUCTS

const drm_mode_card_res = extern struct {
    fb_id_ptr: u64 = 0,
    crtc_id_ptr: u64 = 0,
    connector_id_ptr: u64 = 0,
    encoder_id_ptr: u64 = 0,
    count_fbs: u32 = 0,
    count_crtcs: u32 = 0,
    count_connectors: u32 = 0,
    count_encoders: u32 = 0,
    min_width: u32 = 0,
    max_width: u32 = 0,
    min_height: u32 = 0,
    max_height: u32 = 0,
};

const drm_mode_modeinfo = extern struct {
    clock: u32 = 0,
    hdisplay: u16 = 0,
    hsync_start: u16 = 0,
    hsync_end: u16 = 0,
    htotal: u16 = 0,
    hskew: u16 = 0,
    vdisplay: u16 = 0,
    vsync_start: u16 = 0,
    vsync_end: u16 = 0,
    vtotal: u16 = 0,
    vscan: u16 = 0,
    vrefresh: u32 = 0,
    flags: u32 = 0,
    type: u32 = 0,
    name: [32]u8 = [_]u8{0} ** 32,
};

const drm_mode_get_connector = extern struct {
    encoders_ptr: u64 = 0,
    modes_ptr: u64 = 0,
    props_ptr: u64 = 0,
    prop_values_ptr: u64 = 0,
    count_modes: u32 = 0,
    count_props: u32 = 0,
    count_encoders: u32 = 0,
    encoder_id: u32 = 0,
    connector_id: u32 = 0,
    connector_type: u32 = 0,
    connector_type_id: u32 = 0,
    connection: u32 = 0,
    mm_width: u32 = 0,
    mm_height: u32 = 0,
    subpixel: u32 = 0,
    pad: u32 = 0,
};

const drm_mode_get_encoder = extern struct {
    encoder_id: u32 = 0,
    encoder_type: u32 = 0,
    crtc_id: u32 = 0,
    possible_crtcs: u32 = 0,
    possible_clones: u32 = 0,
};

const drm_mode_create_dumb = extern struct {
    height: u32,
    width: u32,
    bpp: u32,
    flags: u32 = 0,
    handle: u32 = 0,
    pitch: u32 = 0,
    size: u64 = 0,
};

const drm_mode_fb_cmd = extern struct {
    fb_id: u32 = 0,
    width: u32,
    height: u32,
    pitch: u32,
    bpp: u32,
    depth: u32,
    handle: u32,
};

const drm_mode_map_dumb = extern struct {
    handle: u32,
    pad: u32 = 0,
    offset: u64 = 0,
};

const drm_mode_crtc = extern struct {
    set_connectors_ptr: u64 = 0,
    count_connectors: u32 = 0,
    crtc_id: u32 = 0,
    fb_id: u32 = 0,
    x: u32 = 0,
    y: u32 = 0,
    gamma_size: u32 = 0,
    mode_valid: u32 = 0,
    mode: drm_mode_modeinfo = std.mem.zeroInit(drm_mode_modeinfo, .{}),
};

const drm_mode_obj_get_properties = extern struct {
    props_ptr: u64,
    prop_values_ptr: u64,
    count_props: u32,
    obj_id: u32,
    obj_type: u32,
};

const drm_mode_atomic = extern struct {
    flags: u32,
    count_objs: u32,
    objs_ptr: u64,
    count_props_ptr: u64,
    props_ptr: u64,
    prop_values_ptr: u64,
    reserved: u64 = 0,
};

const drm_mode_get_property = extern struct {
    values_ptr: u64 = 0,
    enum_blob_ptr: u64 = 0,
    prop_id: u32,
    flags: u32 = 0,
    name: [32]u8 = [_]u8{0} ** 32,
    count_values: u32 = 0,
    count_enum_blobs: u32 = 0,
};

const drm_version = extern struct {
    version_major: i32 = 0,
    version_minor: i32 = 0,
    version_patchlevel: i32 = 0,
    name_len: usize = 0,
    name: u64 = 0,
    date_len: usize = 0,
    date: u64 = 0,
    desc_len: usize = 0,
    desc: u64 = 0,
};

const drm_mode_get_plane_res = extern struct {
    plane_id_ptr: u64,
    count_planes: u32,
};

pub fn main() void {
    _ = os.mount("devtmpfs", "/dev", "devtmpfs", 0, 0);
    _ = os.mkdirat(os.AT.FDCWD, "/sys", 0o755);
    _ = os.mount("sysfs", "/sys", "sysfs", 0, 0);

    std.debug.print("--- DRM Modern Initiation ---\n", .{});

    working() catch |err| {
        std.debug.print("Critical Failure in Working: {}\n", .{err});
        return;
    };

    scanner() catch |err| {
        std.debug.print("Playground Experiment Failed: {}\n", .{err});
    };

    playground() catch |err| {
        std.debug.print("Playground Experiment Failed: {}\n", .{err});
    };

    while (true) _ = os.nanosleep(&.{ .sec = 1, .nsec = 0 }, null);
}

/// Verified and stable modern code.
/// Verified and stable: Open, Master, Atomic Cap, and Basic IDs
fn working() !void {
    const fd = try posix.openat(posix.AT.FDCWD, "/dev/dri/card0", .{ .ACCMODE = .RDWR }, 0);
    defer _ = os.close(fd);

    _ = posix.system.ioctl(fd, DRM_IOCTL_SET_MASTER, 0);

    // Set Atomic and Universal Caps (Drivers ignore these if they don't support them)
    const caps = [_]struct { id: u64, val: u64 }{
        .{ .id = 3, .val = 1 }, // ATOMIC
        .{ .id = 2, .val = 1 }, // UNIVERSAL_PLANES
    };
    for (caps) |c| _ = posix.system.ioctl(fd, 0x4010640D, @intFromPtr(&c));

    const mem = try posix.mmap(null, 4096, .{ .READ = true, .WRITE = true }, .{ .TYPE = .PRIVATE, .ANONYMOUS = true }, -1, 0);
    defer posix.munmap(mem);

    var res = std.mem.zeroInit(drm_mode_card_res, .{
        .connector_id_ptr = @intFromPtr(mem.ptr),
        .count_connectors = 1,
        .crtc_id_ptr = @intFromPtr(mem.ptr + 1024),
        .count_crtcs = 1,
    });

    if (posix.system.ioctl(fd, DRM_IOCTL_MODE_GETRESOURCES, @intFromPtr(&res)) != 0) return error.GetResFail;

    const conn_id = @as([*]u32, @ptrCast(@alignCast(mem.ptr)))[0];
    const crtc_id = @as([*]u32, @ptrCast(@alignCast(mem.ptr + 1024)))[0];

    std.debug.print("WORKING: Device Ready. Connector: {d}, CRTC: {d}\n", .{ conn_id, crtc_id });
}

/// The Laboratory.
fn playground() !void {
    const fd = try posix.openat(posix.AT.FDCWD, "/dev/dri/card0", .{ .ACCMODE = .RDWR }, 0);
    defer _ = os.close(fd);

    _ = posix.system.ioctl(fd, DRM_IOCTL_SET_MASTER, 0);

    const caps = [_]struct { id: u64, val: u64 }{
        .{ .id = 3, .val = 1 }, // ATOMIC
        .{ .id = 2, .val = 1 }, // UNIVERSAL_PLANES
    };
    for (caps) |c| _ = posix.system.ioctl(fd, 0x4010640D, @intFromPtr(&c));

    const mem = try posix.mmap(null, 32768, .{ .READ = true, .WRITE = true }, .{ .TYPE = .PRIVATE, .ANONYMOUS = true }, -1, 0);
    defer posix.munmap(mem);

    // --- 1. MODE DISCOVERY (CRTC Stealing) ---
    var target_mode: drm_mode_modeinfo = std.mem.zeroInit(drm_mode_modeinfo, .{});
    var crtc_probe = std.mem.zeroInit(drm_mode_crtc, .{ .crtc_id = 37 });

    if (posix.system.ioctl(fd, 0xC06864A1, @intFromPtr(&crtc_probe)) == 0 and crtc_probe.mode_valid != 0) {
        std.debug.print("PLAYGROUND: Stole Mode from CRTC! {d}x{d}\n", .{ crtc_probe.mode.hdisplay, crtc_probe.mode.vdisplay });
        target_mode = crtc_probe.mode;
    } else {
        std.debug.print("PLAYGROUND: CRTC mode invalid. Using Manual Fallback.\n", .{});
        target_mode = std.mem.zeroInit(drm_mode_modeinfo, .{
            .clock = 65000,
            .hdisplay = 1024,
            .hsync_start = 1048,
            .hsync_end = 1184,
            .htotal = 1344,
            .vdisplay = 768,
            .vsync_start = 771,
            .vsync_end = 777,
            .vtotal = 806,
            .vrefresh = 60,
            .type = (1 << 3) | (1 << 6), // USERDEF | PREFERRED
            .flags = (1 << 0), // PHSYNC
        });
        @memcpy(target_mode.name[0..8], "1024x768");
    }

    // --- 2. DUMB BUFFER ---
    var creq = std.mem.zeroInit(drm_mode_create_dumb, .{
        .width = target_mode.hdisplay,
        .height = target_mode.vdisplay,
        .bpp = 32,
    });
    _ = posix.system.ioctl(fd, 0xC02064B2, @intFromPtr(&creq)); // CREATE_DUMB

    // --- 3. FRAMEBUFFER ---
    var fb_req = std.mem.zeroInit(drm_mode_fb_cmd, .{
        .width = creq.width,
        .height = creq.height,
        .pitch = creq.pitch,
        .bpp = 32,
        .depth = 24,
        .handle = creq.handle,
    });
    _ = posix.system.ioctl(fd, 0xC01C64AE, @intFromPtr(&fb_req)); // ADDFB

    // --- 4. MAP & PAINT ---
    var mreq = std.mem.zeroInit(drm_mode_map_dumb, .{ .handle = creq.handle });
    _ = posix.system.ioctl(fd, 0xC01064B3, @intFromPtr(&mreq)); // MAP_DUMB

    const draw_mem = try posix.mmap(null, creq.size, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, fd, mreq.offset);
    defer posix.munmap(draw_mem);

    const pixels = std.mem.bytesAsSlice(u32, draw_mem);
    @memset(pixels, 0xFFFF00FF); // Purple!

    // --- 5. THE MOMENT OF TRUTH: SETCRTC ---
    var set_crtc = std.mem.zeroInit(drm_mode_crtc, .{
        .x = 0,
        .y = 0,
        .crtc_id = 37,
        .fb_id = fb_req.fb_id,
        .count_connectors = 1,
        .set_connectors_ptr = @intFromPtr(&[1]u32{38}),
        .mode_valid = 1,
        .mode = target_mode,
    });

    const rc = posix.system.ioctl(fd, 0xC06864A2, @intFromPtr(&set_crtc)); // SETCRTC

    if (rc == 0) {
        std.debug.print("PLAYGROUND: SUCCESS! Purple screen active.\n", .{});
        const ts = std.os.linux.timespec{ .sec = 10, .nsec = 0 };
        _ = std.os.linux.nanosleep(&ts, null);
    } else {
        const err = @as(i32, @bitCast(@as(u32, @truncate(rc))));
        std.debug.print("PLAYGROUND: SETCRTC failed with {d}\n", .{err});
    }
}
fn scanner() !void {
    const fd = try posix.openat(posix.AT.FDCWD, "/dev/dri/card0", .{ .ACCMODE = .RDWR }, 0);
    defer _ = os.close(fd);

    // Essential: You MUST have Atomic enabled to see Atomic properties!
    const cap = struct { id: u64, val: u64 }{ .id = 3, .val = 1 };
    _ = posix.system.ioctl(fd, 0x4010640D, @intFromPtr(&cap));

    const mem = try posix.mmap(null, 65536, .{ .READ = true, .WRITE = true }, .{ .TYPE = .PRIVATE, .ANONYMOUS = true }, -1, 0);
    defer posix.munmap(mem);

    // We'll scan CRTC 37 specifically since we know it exists
    const target_obj_id: u32 = 37;
    const target_obj_type: u32 = 0xCCCCCCCC; // DRM_MODE_OBJECT_CRTC

    var get_props = std.mem.zeroInit(drm_mode_obj_get_properties, .{
        .obj_id = target_obj_id,
        .obj_type = target_obj_type,
        .props_ptr = @intFromPtr(mem.ptr),
        .prop_values_ptr = @intFromPtr(mem.ptr + 2048),
        .count_props = 32,
    });

    if (posix.system.ioctl(fd, 0xC02064B9, @intFromPtr(&get_props)) == 0) {
        std.debug.print("\n--- Scanning CRTC {d} Properties ---\n", .{target_obj_id});

        const prop_ids = @as([*]u32, @ptrCast(@alignCast(mem.ptr)));
        const prop_values = @as([*]u64, @ptrCast(@alignCast(mem.ptr + 2048)));

        for (0..get_props.count_props) |i| {
            // Now we ask the kernel: "What is the NAME of Property ID X?"
            var prop_info = std.mem.zeroInit(drm_mode_get_property, .{
                .prop_id = prop_ids[i],
            });

            if (posix.system.ioctl(fd, 0xC04064AA, @intFromPtr(&prop_info)) == 0) {
                const name = std.mem.sliceTo(&prop_info.name, 0);
                std.debug.print("Property: {s: <15} | ID: {d: <3} | Value: {d}\n", .{ name, prop_ids[i], prop_values[i] });
            }
        }
    }
    // Add this to your scanner to find the Plane's "Secret" IDs
    for (30..45) |id| {
        var plane_props = std.mem.zeroInit(drm_mode_obj_get_properties, .{
            .obj_id = @as(u32, @intCast(id)), // Tell Zig exactly what this needs to be
            .obj_type = 0xEEEEEEEE,
            .props_ptr = @intFromPtr(mem.ptr),
            .prop_values_ptr = @intFromPtr(mem.ptr + 2048),
            .count_props = 32,
        });

        if (posix.system.ioctl(fd, 0xC02064B9, @intFromPtr(&plane_props)) == 0) {
            std.debug.print("\n--- Found Plane {d} Properties ---\n", .{id});
            const p_ids = @as([*]u32, @ptrCast(@alignCast(mem.ptr)));
            for (0..plane_props.count_props) |i| {
                var p_info = std.mem.zeroInit(drm_mode_get_property, .{ .prop_id = p_ids[i] });
                if (posix.system.ioctl(fd, 0xC04064AA, @intFromPtr(&p_info)) == 0) {
                    std.debug.print("Plane Prop: {s: <15} | ID: {d}\n", .{ std.mem.sliceTo(&p_info.name, 0), p_ids[i] });
                }
            }
            break; // Found our primary plane!
        }
    }
}
