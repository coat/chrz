test "generateChrPixelBuffer single 8x8 tile" {
    const allocator = std.testing.allocator;

    // CHR data from the example.
    const chr_data = [_]u8{
        // Channel 1 (LSB)
        0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0x00, 0x00, 0x00,
        // Channel 2 (MSB)
        0x00, 0x00, 0x3e, 0x3e, 0x3e, 0x3e, 0x3e, 0x00,
    };

    // A sample 4-color palette (Transparent, Light, Medium, Dark)
    const palette = [_]u32{
        0x00000000, // Index 0
        0xff555555, // Index 1 (ch1=1, ch2=0)
        0xffaaaaaa, // Index 2 (ch1=0, ch2=1)
        0xffffffff, // Index 3 (ch1=1, ch2=1)
    };

    const width: u32 = 8;
    const height: u32 = 8;

    var pixel_buffer = try chrToPixelBuffer(allocator, &chr_data, width, height, palette);
    defer pixel_buffer.deinit(allocator);

    // Row 2: ch1=0xf8 (11111000), ch2=0x3e (00111110)
    // Expected indices: 1, 1, 3, 3, 3, 2, 2, 0
    try expectEqual(palette[1], pixel_buffer.data[2 * width + 0]);
    try expectEqual(palette[1], pixel_buffer.data[2 * width + 1]);
    try expectEqual(palette[3], pixel_buffer.data[2 * width + 2]);
    try expectEqual(palette[3], pixel_buffer.data[2 * width + 3]);
    try expectEqual(palette[3], pixel_buffer.data[2 * width + 4]);
    try expectEqual(palette[2], pixel_buffer.data[2 * width + 5]);
    try expectEqual(palette[2], pixel_buffer.data[2 * width + 6]);
    try expectEqual(palette[0], pixel_buffer.data[2 * width + 7]);

    // Row 5: ch1=0x00 (00000000), ch2=0x3e (00111110)
    // Expected indices: 0, 0, 2, 2, 2, 2, 2, 0
    try expectEqual(palette[0], pixel_buffer.data[5 * width + 0]);
    try expectEqual(palette[0], pixel_buffer.data[5 * width + 1]);
    try expectEqual(palette[2], pixel_buffer.data[5 * width + 2]);
    try expectEqual(palette[2], pixel_buffer.data[5 * width + 6]);
    try expectEqual(palette[0], pixel_buffer.data[5 * width + 7]);
}

const chrToPixelBuffer = @import("chrz").chrToPixelBuffer;

const std = @import("std");
const expectEqual = std.testing.expectEqual;
