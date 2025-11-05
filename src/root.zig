pub const chrToPixelBuffer = chr.toPixelBuffer;
pub const chrNmtToPixelBuffer = chr.nmtToPixelBuffer;
pub const chrNmtToChr = chr.nmtToChr;
pub const convertChrToPng = chr.convertChrToPng;
pub const convertPngToChr = chr.convertPngToChr;
pub const createChrFromNmt = chr.createChrFromNmt;

pub const icnToPixelBuffer = icn.toPixelBuffer;
pub const convertPngToIcn = icn.convertPngToIcn;

/// A buffer to hold pixel data for a texture.
/// Pixel format is ARGB8888 (32 bits per pixel).
pub const PixelBuffer = struct {
    data: []u32,
    width: u32,
    height: u32,

    pub fn deinit(self: *@This(), allocator: @import("std").mem.Allocator) void {
        allocator.free(self.data);
        self.* = undefined;
    }
};

pub const Nmt = []NmtEntry;

pub const NmtEntry = packed struct(u24) {
    address: u16,
    sprite: Sprite,

    pub fn toBytes(self: NmtEntry) [3]u8 {
        return @bitCast(self);
    }
};

pub const Sprite = packed struct(u8) {
    palette: u4 = 0,
    flip_x: bool = false,
    flip_y: bool = false,
    layer: bool = false,
    @"2bpp": bool = true,
};

pub const AddressingMode = enum {
    indexed,
    direct,
};

test {
    _ = chr;
    _ = icn;
}

const chr = @import("chr.zig");
const icn = @import("icn.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;
