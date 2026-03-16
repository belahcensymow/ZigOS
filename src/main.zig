const std = @import("std");
const posix = std.posix;
const os = std.os.linux;

// IOCTL Constants
const DRM_IOCTL_SET_MASTER = 0x0000641E;
const DRM_IOCTL_MODE_GETRESOURCES = 0xC04064A0;
const DRM_IOCTL_MODE_CREATE_DUMB = 0xC02064B2;
const DRM_IOCTL_MODE_ADDFB = 0xC01C64AE;
const DRM_IOCTL_MODE_MAP_DUMB = 0xC01064B3;
const DRM_IOCTL_MODE_ATOMIC = 0xC03864BC;
const DRM_IOCTL_MODE_OBJ_GETPROPERTIES = 0xC02064B9;
const DRM_IOCTL_SET_CLIENT_CAP = 0x4010640D;
const DRM_IOCTL_MODE_GETPROPERTY = 0xC04064AA;
const DRM_IOCTL_MODE_CREATEPROPBLOB = 0xC01064BD;

const DRM_MODE_OBJECT_CRTC = 0xCCCCCCCC;
const DRM_MODE_OBJECT_CONNECTOR = 0xC0C0C0C0;
const DRM_MODE_OBJECT_PLANE = 0xEEEEEEEE;

// Kernel Structs
const drm_mode_card_res = extern struct { fb_id_ptr: u64 = 0, crtc_id_ptr: u64 = 0, connector_id_ptr: u64 = 0, encoder_id_ptr: u64 = 0, count_fbs: u32 = 0, count_crtcs: u32 = 0, count_connectors: u32 = 0, count_encoders: u32 = 0, min_width: u32 = 0, max_width: u32 = 0, min_height: u32 = 0, max_height: u32 = 0 };
const drm_mode_modeinfo = extern struct { clock: u32 = 0, hdisplay: u16 = 0, hsync_start: u16 = 0, hsync_end: u16 = 0, htotal: u16 = 0, hskew: u16 = 0, vdisplay: u16 = 0, vsync_start: u16 = 0, vsync_end: u16 = 0, vtotal: u16 = 0, vscan: u16 = 0, vrefresh: u32 = 0, flags: u32 = 0, type: u32 = 0, name: [32]u8 = [_]u8{0} ** 32 };
const drm_mode_create_dumb = extern struct { height: u32, width: u32, bpp: u32, flags: u32 = 0, handle: u32 = 0, pitch: u32 = 0, size: u64 = 0 };
const drm_mode_fb_cmd = extern struct { fb_id: u32 = 0, width: u32, height: u32, pitch: u32, bpp: u32, depth: u32, handle: u32 };
const drm_mode_map_dumb = extern struct { handle: u32, pad: u32 = 0, offset: u64 = 0 };
const drm_mode_obj_get_properties = extern struct { props_ptr: u64, prop_values_ptr: u64, count_props: u32, obj_id: u32, obj_type: u32 };
const drm_mode_atomic = extern struct { flags: u32, count_objs: u32, objs_ptr: u64, count_props_ptr: u64, props_ptr: u64, prop_values_ptr: u64, reserved: u64 = 0 };
const drm_mode_get_property = extern struct { values_ptr: u64 = 0, enum_blob_ptr: u64 = 0, prop_id: u32, flags: u32 = 0, name: [32]u8 = [_]u8{0} ** 32, count_values: u32 = 0, count_enum_blobs: u32 = 0 };
const drm_mode_get_plane_res = extern struct { plane_id_ptr: u64, count_planes: u32 };
const Core = struct {
    fd: i32,

    fn init() !Core {
        const fd = try posix.openat(posix.AT.FDCWD, "/dev/dri/card0", .{ .ACCMODE = .RDWR }, 0);
        _ = posix.system.ioctl(fd, DRM_IOCTL_SET_MASTER, 0);

        const caps = [_]struct { id: u64, val: u64 }{
            .{ .id = 3, .val = 1 }, // ATOMIC
            .{ .id = 2, .val = 1 }, // UNIVERSAL_PLANES
        };
        for (caps) |c| _ = posix.system.ioctl(fd, DRM_IOCTL_SET_CLIENT_CAP, @intFromPtr(&c));

        return Core{ .fd = fd };
    }
};

const Surface = struct {
    fb_id: u32,
    ptr: []u32,

    fn init(fd: i32, w: u32, h: u32) !Surface {
        var creq = std.mem.zeroInit(drm_mode_create_dumb, .{ .width = w, .height = h, .bpp = 32 });
        _ = posix.system.ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, @intFromPtr(&creq));

        var fb_req = std.mem.zeroInit(drm_mode_fb_cmd, .{
            .width = w,
            .height = h,
            .pitch = creq.pitch,
            .bpp = 32,
            .depth = 24,
            .handle = creq.handle,
        });
        _ = posix.system.ioctl(fd, DRM_IOCTL_MODE_ADDFB, @intFromPtr(&fb_req));

        var mreq = std.mem.zeroInit(drm_mode_map_dumb, .{ .handle = creq.handle });
        _ = posix.system.ioctl(fd, DRM_IOCTL_MODE_MAP_DUMB, @intFromPtr(&mreq));

        const draw_mem = try posix.mmap(null, creq.size, os.PROT.READ | os.PROT.WRITE, .{ .TYPE = .SHARED }, fd, mreq.offset);
        return Surface{ .fb_id = fb_req.fb_id, .ptr = std.mem.bytesAsSlice(u32, draw_mem) };
    }
};

const Output = struct {
    connector_id: u32,
    crtc_id: u32,
    plane_id: u32,

    // Property IDs
    c_active: u32,
    c_mode: u32,
    p_fb: u32,
    p_crtc: u32,
    p_cw: u32,
    p_ch: u32,
    p_sw: u32,
    p_sh: u32,
    p_sx: u32,
    p_sy: u32,
    conn_crtc: u32,

    fn init(fd: i32) !Output {
        // --- DYNAMIC CONNECTOR DISCOVERY (MMAP VERSION) ---
        // 1. Map a scratchpad for the kernel to write into
        const mem = try posix.mmap(null, 4096, os.PROT.READ | os.PROT.WRITE, .{ .TYPE = .PRIVATE, .ANONYMOUS = true }, -1, 0);
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

        // 2. DYNAMIC PLANE SEARCH (The "See Them All" Version)
        var primary_plane: u32 = 0;
        var search_id: u32 = 1;

        std.debug.print("\n--- Scanning Plane ID Space (1-255) ---\n", .{});
        while (search_id < 255) : (search_id += 1) {
            var get_props = std.mem.zeroInit(drm_mode_obj_get_properties, .{
                .obj_id = search_id,
                .obj_type = DRM_MODE_OBJECT_PLANE,
                .props_ptr = 0,
                .prop_values_ptr = 0,
                .count_props = 0,
            });

            if (posix.system.ioctl(fd, DRM_IOCTL_MODE_OBJ_GETPROPERTIES, @intFromPtr(&get_props)) == 0) {
                // If we hit a successful IOCTL, this ID is a plane.
                // We'll use the first one we find as our main drawing plane.
                if (primary_plane == 0) primary_plane = search_id;

                std.debug.print("Found Plane Entity: ID {d} ({d} properties)\n", .{ search_id, get_props.count_props });
            }
        }
        std.debug.print("---------------------------------------\n", .{});

        if (primary_plane == 0) return error.NoPlaneFound;

        std.debug.print("DYNAMIC DISCOVERY COMPLETE: Conn {d}, CRTC {d}, Primary Plane {d}\n\n", .{ conn_id, crtc_id, primary_plane });

        return Output{
            .connector_id = conn_id,
            .crtc_id = crtc_id,
            .plane_id = primary_plane,
            // Property discovery uses the first plane we found
            .c_active = try getPropId(fd, crtc_id, DRM_MODE_OBJECT_CRTC, "ACTIVE"),
            .c_mode = try getPropId(fd, crtc_id, DRM_MODE_OBJECT_CRTC, "MODE_ID"),
            .p_fb = try getPropId(fd, primary_plane, DRM_MODE_OBJECT_PLANE, "FB_ID"),
            .p_crtc = try getPropId(fd, primary_plane, DRM_MODE_OBJECT_PLANE, "CRTC_ID"),
            .p_cw = try getPropId(fd, primary_plane, DRM_MODE_OBJECT_PLANE, "CRTC_W"),
            .p_ch = try getPropId(fd, primary_plane, DRM_MODE_OBJECT_PLANE, "CRTC_H"),
            .p_sw = try getPropId(fd, primary_plane, DRM_MODE_OBJECT_PLANE, "SRC_W"),
            .p_sh = try getPropId(fd, primary_plane, DRM_MODE_OBJECT_PLANE, "SRC_H"),
            .p_sx = try getPropId(fd, primary_plane, DRM_MODE_OBJECT_PLANE, "SRC_X"),
            .p_sy = try getPropId(fd, primary_plane, DRM_MODE_OBJECT_PLANE, "SRC_Y"),
            .conn_crtc = try getPropId(fd, conn_id, DRM_MODE_OBJECT_CONNECTOR, "CRTC_ID"),
        };
    }
};

pub fn main() void {
    _ = os.mount("devtmpfs", "/dev", "devtmpfs", 0, 0);
    _ = os.mkdirat(os.AT.FDCWD, "/sys", 0o755);
    _ = os.mount("sysfs", "/sys", "sysfs", 0, 0);

    std.debug.print("--- DRM Modern Initiation ---\n", .{});

    const core = Core.init() catch |err| {
        std.debug.print("Core Init Fail: {}\n", .{err});
        return;
    };

    scanner(core.fd) catch {};

    const out = Output.init(core.fd) catch |err| {
        std.debug.print("Output Init Fail: {}\n", .{err});
        return;
    };

    const w = 1280;
    const h = 800;
    var buffers = [2]Surface{
        Surface.init(core.fd, w, h) catch unreachable,
        Surface.init(core.fd, w, h) catch unreachable,
    };

    var frame: u32 = 0;
    while (true) : (frame += 1) {
        const back = &buffers[frame % 2];
        const intensity = @as(u32, @intCast(frame % 255));
        const color = (intensity << 16) | (255 - intensity);
        @memset(back.ptr, 0xFF000000 | color);

        var objs = [_]u32{ out.crtc_id, out.plane_id, out.connector_id };
        var p_counts = [_]u32{ 2, 8, 1 };
        var props = [_]u32{
            out.c_active,  out.c_mode,
            out.p_fb,      out.p_crtc,
            out.p_cw,      out.p_ch,
            out.p_sw,      out.p_sh,
            out.p_sx,      out.p_sy,
            out.conn_crtc,
        };
        var values = [_]u64{
            1,                 42,
            back.fb_id,        out.crtc_id,
            w,                 h,
            @as(u64, w) << 16, @as(u64, h) << 16,
            0,                 0,
            out.crtc_id,
        };

        var req = std.mem.zeroInit(drm_mode_atomic, .{
            .flags = if (frame == 0) @as(u32, 0x0100) else 0,
            .count_objs = 3,
            .objs_ptr = @intFromPtr(&objs),
            .count_props_ptr = @intFromPtr(&p_counts),
            .props_ptr = @intFromPtr(&props),
            .prop_values_ptr = @intFromPtr(&values),
        });

        if (posix.system.ioctl(core.fd, DRM_IOCTL_MODE_ATOMIC, @intFromPtr(&req)) != 0) {
            std.debug.print("Atomic Flip Failed at frame {d}\n", .{frame});
            break;
        }
        _ = os.nanosleep(&.{ .sec = 0, .nsec = 16_666_666 }, null);
    }
}

fn getPropId(fd: i32, obj_id: u32, obj_type: u32, target_name: []const u8) !u32 {
    var ids: [64]u32 = undefined;
    var values: [64]u64 = undefined;
    var props_req = std.mem.zeroInit(drm_mode_obj_get_properties, .{
        .obj_id = obj_id,
        .obj_type = obj_type,
        .props_ptr = @intFromPtr(&ids),
        .prop_values_ptr = @intFromPtr(&values),
        .count_props = 64,
    });
    if (posix.system.ioctl(fd, DRM_IOCTL_MODE_OBJ_GETPROPERTIES, @intFromPtr(&props_req)) != 0) return error.IoctlFailed;
    for (ids[0..props_req.count_props]) |id| {
        var info = std.mem.zeroInit(drm_mode_get_property, .{ .prop_id = id });
        if (posix.system.ioctl(fd, DRM_IOCTL_MODE_GETPROPERTY, @intFromPtr(&info)) == 0) {
            if (std.mem.eql(u8, std.mem.sliceTo(&info.name, 0), target_name)) return id;
        }
    }
    return error.PropertyNotFound;
}

fn scanner(fd: i32) !void {
    const mem = try posix.mmap(null, 65536, os.PROT.READ | os.PROT.WRITE, .{ .TYPE = .PRIVATE, .ANONYMOUS = true }, -1, 0);
    defer posix.munmap(mem);
    const target_obj_id: u32 = 37;
    var get_props = std.mem.zeroInit(drm_mode_obj_get_properties, .{
        .obj_id = target_obj_id,
        .obj_type = DRM_MODE_OBJECT_CRTC,
        .props_ptr = @intFromPtr(mem.ptr),
        .prop_values_ptr = @intFromPtr(mem.ptr + 2048),
        .count_props = 32,
    });
    if (posix.system.ioctl(fd, DRM_IOCTL_MODE_OBJ_GETPROPERTIES, @intFromPtr(&get_props)) == 0) {
        std.debug.print("\n--- Scanning CRTC {d} Properties ---\n", .{target_obj_id});
        const prop_ids = @as([*]u32, @ptrCast(@alignCast(mem.ptr)));
        for (0..get_props.count_props) |i| {
            var prop_info = std.mem.zeroInit(drm_mode_get_property, .{ .prop_id = prop_ids[i] });
            if (posix.system.ioctl(fd, DRM_IOCTL_MODE_GETPROPERTY, @intFromPtr(&prop_info)) == 0) {
                std.debug.print("Property: {s: <15} | ID: {d}\n", .{ std.mem.sliceTo(&prop_info.name, 0), prop_ids[i] });
            }
        }
    }
}
