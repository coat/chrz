pub const chrToPixelBuffer = chr.toPixelBuffer;
pub const chrNmtToPixelBuffer = chr.nmtToPixelBuffer;
pub const chrNmtToChr = chr.nmtToChr;
pub const convertChrToPng = chr.convertChrToPng;
pub const convertPngToChr = chr.convertPngToChr;
pub const createChrFromNmt = chr.createChrFromNmt;

pub const icnToPixelBuffer = icn.toPixelBuffer;
pub const convertPngToIcn = icn.convertPngToIcn;

pub const Nmt = nmt.Nmt;
pub const NmtEntry = nmt.NmtEntry;
pub const Sprite = nmt.Sprite;
pub const AddressingMode = nmt.AddressingMode;
pub const nmtFromBytes = nmt.fromBytes;

/// A buffer to hold pixel data for a texture.
pub fn PixelBuffer(T: type) type {
    return struct {
        data: []T,
        width: u32,
        height: u32,

        pub fn deinit(self: *@This(), allocator: @import("std").mem.Allocator) void {
            allocator.free(self.data);
            self.* = undefined;
        }
    };
}

test {
    _ = chr;
    _ = icn;
}

const chr = @import("chr.zig");
const icn = @import("icn.zig");
const nmt = @import("nmt.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;