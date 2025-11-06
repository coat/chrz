test "generateIcnPixelBuffer single 8x8 tile" {
    const allocator = std.testing.allocator;

    // A simple 8x8 tile representing a smiley face.
    const icn_data = [_]u8{
        0b00111100,
        0b01000010,
        0b10100101,
        0b10000001,
        0b10100101,
        0b10011001,
        0b01000010,
        0b00111100,
    };

    const color: u32 = 0xff123456;
    const transparent: u32 = 0;
    const width: u32 = 8;
    const height: u32 = 8;

    var pixel_buffer = try toPixelBuffer(u32, allocator, &icn_data, width, height, color);
    defer pixel_buffer.deinit(allocator);

    try std.testing.expectEqual(width, pixel_buffer.width);
    try std.testing.expectEqual(height, pixel_buffer.height);
    try std.testing.expectEqual(width * height, pixel_buffer.data.len);

    // Spot-check a few pixels to verify correctness
    // First row (y=0): 00111100
    try std.testing.expectEqual(transparent, pixel_buffer.data[0 * width + 0]);
    try std.testing.expectEqual(transparent, pixel_buffer.data[0 * width + 1]);
    try std.testing.expectEqual(color, pixel_buffer.data[0 * width + 2]);
    try std.testing.expectEqual(color, pixel_buffer.data[0 * width + 5]);
    try std.testing.expectEqual(transparent, pixel_buffer.data[0 * width + 6]);
    try std.testing.expectEqual(transparent, pixel_buffer.data[0 * width + 7]);

    // Third row (y=2): 10100101
    try std.testing.expectEqual(color, pixel_buffer.data[2 * width + 0]);
    try std.testing.expectEqual(transparent, pixel_buffer.data[2 * width + 1]);
    try std.testing.expectEqual(color, pixel_buffer.data[2 * width + 2]);
    try std.testing.expectEqual(color, pixel_buffer.data[2 * width + 5]);
    try std.testing.expectEqual(transparent, pixel_buffer.data[2 * width + 6]);
    try std.testing.expectEqual(color, pixel_buffer.data[2 * width + 7]);
}

test "generateIcnPixelBuffer multiple horizontal tiles (16x8)" {
    const allocator = std.testing.allocator;

    const tile1 = [_]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };
    const tile2 = [_]u8{ 0xff, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xff };

    var icn_data_list = std.ArrayList(u8).empty;
    defer icn_data_list.deinit(allocator);
    try icn_data_list.appendSlice(allocator, &tile1);
    try icn_data_list.appendSlice(allocator, &tile2);
    const icn_data = icn_data_list.items;

    const color: u32 = 0xffffffff;
    const transparent: u32 = 0;
    const width: u32 = 16;
    const height: u32 = 8;

    var pixel_buffer = try toPixelBuffer(u32, allocator, icn_data, width, height, color);
    defer pixel_buffer.deinit(allocator);

    // Check pixel in first tile area (x < 8)
    try std.testing.expectEqual(color, pixel_buffer.data[1 * width + 1]); // y=1, x=1

    // Check pixel in second tile area (x >= 8)
    // From tile2, row 1 (y=1), value is 0x81 -> 10000001
    try std.testing.expectEqual(color, pixel_buffer.data[1 * width + 8]); // y=1, x=8
    try std.testing.expectEqual(transparent, pixel_buffer.data[1 * width + 9]); // y=1, x=9
    try std.testing.expectEqual(color, pixel_buffer.data[1 * width + 15]); // y=1, x=15
}

test "generateIcnPixelBuffer multiple row and column tiles (16x16)" {
    const allocator = std.testing.allocator;

    const t00 = [_]u8{ 0x80, 0, 0, 0, 0, 0, 0, 0 };
    const t01 = [_]u8{ 0x01, 0, 0, 0, 0, 0, 0, 0 };
    const t10 = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0x80 };
    const t11 = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0x01 };

    var icn_data_list = std.ArrayList(u8).empty;
    defer icn_data_list.deinit(allocator);
    try icn_data_list.appendSlice(allocator, &t00);
    try icn_data_list.appendSlice(allocator, &t01);
    try icn_data_list.appendSlice(allocator, &t10);
    try icn_data_list.appendSlice(allocator, &t11);
    const icn_data = icn_data_list.items;

    const color: u32 = 0xffaabbcc;
    const transparent: u32 = 0;
    const width: u32 = 16;
    const height: u32 = 16;

    var pixel_buffer = try toPixelBuffer(u32, allocator, icn_data, width, height, color);
    defer pixel_buffer.deinit(allocator);

    // Explicitly check the corners of the 16x16 grid
    try std.testing.expectEqual(color, pixel_buffer.data[0 * width + 0]); // Top-left from T00
    try std.testing.expectEqual(color, pixel_buffer.data[0 * width + 15]); // Top-right from T01
    try std.testing.expectEqual(color, pixel_buffer.data[15 * width + 0]); // Bottom-left from T10
    try std.testing.expectEqual(color, pixel_buffer.data[15 * width + 15]); // Bottom-right from T11

    // Check a non-corner pixel to ensure it's transparent
    try std.testing.expectEqual(transparent, pixel_buffer.data[1 * width + 1]);
}

test "generateIcnPixelBuffer handles incomplete trailing data" {
    const allocator = std.testing.allocator;

    const icn_data = [_]u8{
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // Full tile
        0x1, 0x2, 0x3, 0x4, // Incomplete tile
    };

    const color: u32 = 0xff112233;
    const transparent: u32 = 0;
    const width: u32 = 16;
    const height: u32 = 8;

    var pixel_buffer = try toPixelBuffer(u32, allocator, &icn_data, width, height, color);
    defer pixel_buffer.deinit(allocator);

    // The first 8x8 area should be solid color
    try std.testing.expectEqual(color, pixel_buffer.data[0 * width + 0]);
    try std.testing.expectEqual(color, pixel_buffer.data[7 * width + 7]);

    // The area for the second tile should be transparent because the data was incomplete
    try std.testing.expectEqual(transparent, pixel_buffer.data[0 * width + 8]);
    try std.testing.expectEqual(transparent, pixel_buffer.data[7 * width + 15]);
}

const std = @import("std");
const expectEqual = std.testing.expectEqual;

const toPixelBuffer = @import("chrz").icnToPixelBuffer;
