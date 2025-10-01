pub const chrToPixelBuffer = chr.toPixelBuffer;
pub const icnToPixelBuffer = icn.toPixelBuffer;

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

pub const Nmt = extern struct {
    address: u16,
    sprite: Sprite,
};

pub const Sprite = extern struct {
    color: u2 = 0,
    _: u2 = 0,
    flip_x: bool = false,
    flip_y: bool = false,
    layer: bool = false,
    @"2bpp": bool = true,
};

test {
    _ = chr;
    _ = icn;
}

const chr = @import("chr.zig");
const icn = @import("icn.zig");
