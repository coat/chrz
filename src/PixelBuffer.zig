/// A buffer to hold pixel data for a texture.
/// Pixel format is ARGB8888 (32 bits per pixel).
data: []u32,
width: u32,
height: u32,

pub fn deinit(self: *@This(), allocator: Allocator) void {
    allocator.free(self.data);
    self.* = undefined;
}

const Allocator = @import("std").mem.Allocator;
