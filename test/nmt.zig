test "NmtEntry toBytes" {
    const entry = NmtEntry{
        .address = 0x1234,
        .sprite = .{
            .palette = 5,
            .flip_x = true,
            .flip_y = false,
            .layer = true,
            .@"2bpp" = false,
        },
    };

    const bytes = entry.toBytes();
    try expectEqual(0x34, bytes[0]);
    try expectEqual(0x12, bytes[1]);
    try expectEqual(0b01010101, bytes[2]);
}

test "NmtEntry fromBytes" {
    const bytes = [_]u8{ 0xab, 0xcd, 0b10101010 };
    const entry = NmtEntry.fromBytes(&bytes);

    try expectEqual(0xcdab, entry.address);
    try expectEqual(0b1010, entry.sprite.palette);
    try expectEqual(false, entry.sprite.flip_x);
    try expectEqual(true, entry.sprite.flip_y);
    try expectEqual(false, entry.sprite.layer);
    try expectEqual(true, entry.sprite.@"2bpp");
}

test "NmtEntry roundtrip" {
    const original = NmtEntry{
        .address = 0x5678,
        .sprite = .{
            .palette = 15,
            .flip_x = false,
            .flip_y = true,
            .layer = false,
            .@"2bpp" = true,
        },
    };

    const bytes = original.toBytes();
    const decoded = NmtEntry.fromBytes(&bytes);

    try expectEqual(original.address, decoded.address);
    try expectEqual(original.sprite.palette, decoded.sprite.palette);
    try expectEqual(original.sprite.flip_x, decoded.sprite.flip_x);
    try expectEqual(original.sprite.flip_y, decoded.sprite.flip_y);
    try expectEqual(original.sprite.layer, decoded.sprite.layer);
    try expectEqual(original.sprite.@"2bpp", decoded.sprite.@"2bpp");
}

test "Sprite default values" {
    const sprite = Sprite{};

    try expectEqual(0, sprite.palette);
    try expectEqual(false, sprite.flip_x);
    try expectEqual(false, sprite.flip_y);
    try expectEqual(false, sprite.layer);
    try expectEqual(true, sprite.@"2bpp");
}

test "Sprite packed layout" {
    const sprite = Sprite{
        .palette = 0b1111,
        .flip_x = true,
        .flip_y = true,
        .layer = true,
        .@"2bpp" = true,
    };

    const byte: u8 = @bitCast(sprite);
    try expectEqual(0b11111111, byte);
}

test "fromBytes parses NMT data" {
    const allocator = std.testing.allocator;

    const nmt_data = [_]u8{
        0x00, 0x10, 0b00000101,
        0x20, 0x30, 0b00101010,
        0xff, 0x7f, 0b11111111,
    };

    const nmt = try fromBytes(allocator, &nmt_data);
    defer allocator.free(nmt);

    try expectEqual(3, nmt.len);

    try expectEqual(0x1000, nmt[0].address);
    try expectEqual(5, nmt[0].sprite.palette);
    try expectEqual(false, nmt[0].sprite.flip_x);
    try expectEqual(false, nmt[0].sprite.flip_y);

    try expectEqual(0x3020, nmt[1].address);
    try expectEqual(10, nmt[1].sprite.palette);
    try expectEqual(false, nmt[1].sprite.flip_x);
    try expectEqual(true, nmt[1].sprite.flip_y);

    try expectEqual(0x7fff, nmt[2].address);
    try expectEqual(15, nmt[2].sprite.palette);
    try expectEqual(true, nmt[2].sprite.flip_x);
    try expectEqual(true, nmt[2].sprite.flip_y);
    try expectEqual(true, nmt[2].sprite.layer);
    try expectEqual(true, nmt[2].sprite.@"2bpp");
}

const NmtEntry = @import("chrz").NmtEntry;
const Sprite = @import("chrz").Sprite;
const fromBytes = @import("chrz").nmtFromBytes;
const std = @import("std");
const expectEqual = std.testing.expectEqual;