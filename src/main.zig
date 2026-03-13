const std = @import("std");
const posix = std.posix;

// --- IOCTL & CONSTANTS ---
const DRM_IOCTL_SET_MASTER = 0x0000641E;
const DRM_IOCTL_MODE_CREATE_DUMB = 0xC02064B2;
const DRM_IOCTL_MODE_ADDFB = 0xC01C64AE;
const DRM_IOCTL_MODE_MAP_DUMB = 0xC01064B3;
const DRM_IOCTL_MODE_ATOMIC = 0xC03864BC;
const DRM_IOCTL_MODE_OBJ_GETPROPERTIES = 0xC02064B9;
const DRM_IOCTL_MODE_GETPROPERTY = 0xC04064AA;
const DRM_IOCTL_SET_CLIENT_CAP = 0x4010640D;

const DRM_MODE_OBJECT_CRTC = 0xCCCCCCCC;
const DRM_MODE_OBJECT_CONNECTOR = 0xC0C0C0C0;
const DRM_MODE_OBJECT_PLANE = 0xEEEEEEEE;

// --- KERNEL STRUCTS ---
const drm_mode_create_dumb = extern struct { height: u32, width: u32, bpp: u32, flags: u32 = 0, handle: u32 = 0, pitch: u32 = 0, size: u64 = 0 };
const drm_mode_fb_cmd = extern struct { fb_id: u32 = 0, width: u32, height: u32, pitch: u32, bpp: u32, depth: u32, handle: u32 };
const drm_mode_map_dumb = extern struct { handle: u32, pad: u32 = 0, offset: u64 = 0 };
const drm_mode_obj_get_properties = extern struct { props_ptr: u64, prop_values_ptr: u64, count_props: u32, obj_id: u32, obj_type: u32 };
const drm_mode_get_property = extern struct { values_ptr: u64 = 0, enum_blob_ptr: u64 = 0, prop_id: u32, flags: u32 = 0, name: [32]u8 = [_]u8{0} ** 32, count_values: u32 = 0, count_enum_blobs: u32 = 0 };
const drm_mode_atomic = extern struct { flags: u32, count_objs: u32, objs_ptr: u64, count_props_ptr: u64, props_ptr: u64, prop_values_ptr: u64, reserved: u64 = 0 };

// --- CORE ARCHITECTURE ---

/// Phase 1: The "Master" Node [cite: 1, 18]
pub const Core = struct {
    fd: i32,

    pub fn init(path: []const u8) !Core {
        const fd = try posix.openat(posix.AT.FDCWD, path, .{ .ACCMODE = .RDWR }, 0);
        _ = posix.system.ioctl(fd, DRM_IOCTL_SET_MASTER, 0);

        // Client Caps: Universal Planes & Atomic [cite: 1, 3]
        const caps = [_][2]u64{ .{ 2, 1 }, .{ 3, 1 } };
        for (caps) |c| _ = posix.system.ioctl(fd, DRM_IOCTL_SET_CLIENT_CAP, @intFromPtr(&c));

        return .{ .fd = fd };
    }

    pub fn getPropId(self: Core, obj_id: u32, obj_type: u32, name: []const u8) u32 {
        var ids: [64]u32 = undefined;
        var vals: [64]u64 = undefined;
        var req = std.mem.zeroInit(drm_mode_obj_get_properties, .{
            .obj_id = obj_id,
            .obj_type = obj_type,
            .props_ptr = @intFromPtr(&ids),
            .prop_values_ptr = @intFromPtr(&vals),
            .count_props = 64,
        });

        if (posix.system.ioctl(self.fd, DRM_IOCTL_MODE_OBJ_GETPROPERTIES, @intFromPtr(&req)) != 0) return 0;
        for (ids[0..req.count_props]) |id| {
            var info = std.mem.zeroInit(drm_mode_get_property, .{ .prop_id = id });
            if (posix.system.ioctl(self.fd, DRM_IOCTL_MODE_GETPROPERTY, @intFromPtr(&info)) == 0) {
                if (std.mem.eql(u8, std.mem.sliceTo(&info.name, 0), name)) return id;
            }
        }
        return 0;
    }
};

/// Phase 3: The Surface Abstraction [cite: 10, 20]
pub const Surface = struct {
    fb_id: u32,
    ptr: []u32,
    width: u32,
    height: u32,
    pitch: u32,

    pub fn init(core: Core, w: u32, h: u32) !Surface {
        var creq = std.mem.zeroInit(drm_mode_create_dumb, .{ .width = w, .height = h, .bpp = 32 });
        _ = posix.system.ioctl(core.fd, DRM_IOCTL_MODE_CREATE_DUMB, @intFromPtr(&creq));

        var fb_req = std.mem.zeroInit(drm_mode_fb_cmd, .{
            .width = w,
            .height = h,
            .pitch = creq.pitch,
            .bpp = 32,
            .depth = 24,
            .handle = creq.handle,
        });
        _ = posix.system.ioctl(core.fd, DRM_IOCTL_MODE_ADDFB, @intFromPtr(&fb_req));

        var mreq = std.mem.zeroInit(drm_mode_map_dumb, .{ .handle = creq.handle });
        _ = posix.system.ioctl(core.fd, DRM_IOCTL_MODE_MAP_DUMB, @intFromPtr(&mreq));

        const mem = try posix.mmap(null, creq.size, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, core.fd, mreq.offset);
        return .{
            .fb_id = fb_req.fb_id,
            .ptr = std.mem.bytesAsSlice(u32, mem),
            .width = w,
            .height = h,
            .pitch = creq.pitch,
        };
    }
};

/// Phase 1 & 4: Output Management [cite: 15, 18]
pub const Output = struct {
    core: Core,
    crtc_id: u32,
    conn_id: u32,
    plane_id: u32,
    props: struct {
        c_active: u32,
        c_mode: u32,
        p_fb: u32,
        p_crtc: u32,
        p_cw: u32,
        p_ch: u32,
        p_sw: u32,
        p_sh: u32,
        conn_crtc: u32,
    },

    pub fn init(core: Core, crtc: u32, conn: u32, plane: u32) !Output {
        return .{
            .core = core,
            .crtc_id = crtc,
            .conn_id = conn,
            .plane_id = plane,
            .props = .{
                .c_active = core.getPropId(crtc, DRM_MODE_OBJECT_CRTC, "ACTIVE"),
                .c_mode = core.getPropId(crtc, DRM_MODE_OBJECT_CRTC, "MODE_ID"),
                .p_fb = core.getPropId(plane, DRM_MODE_OBJECT_PLANE, "FB_ID"),
                .p_crtc = core.getPropId(plane, DRM_MODE_OBJECT_PLANE, "CRTC_ID"),
                .p_cw = core.getPropId(plane, DRM_MODE_OBJECT_PLANE, "CRTC_W"),
                .p_ch = core.getPropId(plane, DRM_MODE_OBJECT_PLANE, "CRTC_H"),
                .p_sw = core.getPropId(plane, DRM_MODE_OBJECT_PLANE, "SRC_W"),
                .p_sh = core.getPropId(plane, DRM_MODE_OBJECT_PLANE, "SRC_H"),
                .conn_crtc = core.getPropId(conn, DRM_MODE_OBJECT_CONNECTOR, "CRTC_ID"),
            },
        };
    }

    pub fn commit(self: Output, surface: Surface, is_modeset: bool) !void {
        var objs = [_]u32{ self.crtc_id, self.plane_id, self.conn_id };
        var counts = [_]u32{ 2, 6, 1 };
        var props = [_]u32{
            self.props.c_active,  self.props.c_mode,
            self.props.p_fb,      self.props.p_crtc,
            self.props.p_cw,      self.props.p_ch,
            self.props.p_sw,      self.props.p_sh,
            self.props.conn_crtc,
        };
        var vals = [_]u64{
            1,                             42,
            surface.fb_id,                 self.crtc_id,
            surface.width,                 surface.height,
            @as(u64, surface.width) << 16, @as(u64, surface.height) << 16,
            self.crtc_id,
        };

        var req = std.mem.zeroInit(drm_mode_atomic, .{
            .flags = if (is_modeset) @as(u32, 0x0100) else @as(u32, 0),
            .count_objs = 3,
            .objs_ptr = @intFromPtr(&objs),
            .count_props_ptr = @intFromPtr(&counts),
            .props_ptr = @intFromPtr(&props),
            .prop_values_ptr = @intFromPtr(&vals),
        });

        // This ioctl will now naturally block until VBLANK, stopping the "too fast" flashing
        if (posix.system.ioctl(self.core.fd, DRM_IOCTL_MODE_ATOMIC, @intFromPtr(&req)) != 0) return error.AtomicFailed;
    }
};

pub fn main() !void {
    // Necessary setup to avoid Kernel Panic
    _ = std.os.linux.mount("devtmpfs", "/dev", "devtmpfs", 0, 0);
    _ = std.os.linux.mount("sysfs", "/sys", "sysfs", 0, 0);

    const core = try Core.init("/dev/dri/card0");
    const out = try Output.init(core, 37, 38, 33);

    // Phase 2: Double Buffering [cite: 8]
    var swp = [_]Surface{ try Surface.init(core, 1280, 800), try Surface.init(core, 1280, 800) };

    var frame: u32 = 0;
    while (true) : (frame += 1) {
        const surf = swp[frame % 2];

        // Slower animation logic
        const pulse = @as(u32, @intCast((frame / 2) % 255));
        @memset(surf.ptr, 0xFF000000 | (pulse << 16) | (255 - pulse));

        // Atomic Commit throttles the loop to the monitor's refresh rate
        try out.commit(surf, frame == 0);
    }
}
