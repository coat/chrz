pub const Nmt = []NmtEntry;

pub const NmtEntry = packed struct(u24) {
    address: u16,
    sprite: Sprite,

    pub fn toBytes(self: NmtEntry) [3]u8 {
        return @bitCast(self);
    }

    pub fn fromBytes(bytes: []const u8) NmtEntry {
        const address = std.mem.readInt(u16, bytes[0..2], .little);
        const sprite = @as(Sprite, @bitCast(bytes[2]));
        return .{
            .address = address,
            .sprite = sprite,
        };
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

const cell_size = 3;
pub fn fromBytes(alloc: std.mem.Allocator, nmt_data: []const u8) !Nmt {
    const nmt = try alloc.alloc(NmtEntry, nmt_data.len / cell_size);
    errdefer alloc.free(nmt);

    var cell_index: u32 = 0;
    while (cell_index * cell_size + cell_size <= nmt_data.len) : (cell_index += 1) {
        const cell_start = cell_index * cell_size;
        const cell = nmt_data[cell_start..][0..cell_size];
        const address = std.mem.readInt(u16, cell[0..2], .little);
        const sprite = @as(Sprite, @bitCast(cell[2]));
        nmt[cell_index] = .{
            .address = address,
            .sprite = sprite,
        };
    }

    return nmt;
}

const std = @import("std");