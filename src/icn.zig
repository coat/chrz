/// Generates a 32-bit pixel buffer from 1-bit ICN data.
///
/// ICN data is a series of 8x8 tiles, where each tile is 8 bytes. Each bit
/// within those bytes corresponds to a pixel.
///
/// Parameters:
/// - allocator: The memory allocator to use for the pixel buffer.
/// - icn_data: A slice of bytes representing the ICN file data.
/// - width: The width of the target pixel buffer.
/// - height: The height of the target pixel buffer.
/// - color: The ARGB8888 color to use for the set pixels
///
/// Returns:
/// A `PixelBuffer` containing the generated pixel data, or an error if
/// memory allocation fails.
pub fn toPixelBuffer(
    allocator: Allocator,
    icn_data: []const u8,
    width: u32,
    height: u32,
    color: u32,
) !PixelBuffer {
    const pixel_count = width * height;
    const data = try allocator.alloc(u32, pixel_count);

    // Initialize the buffer to be fully transparent (black).
    @memset(data, 0);

    const tiles_wide = width / 8;
    const tile_byte_size = 8;

    // Iterate over each 8-byte tile in the input data.
    var tile_index: u32 = 0;
    while (tile_index * tile_byte_size <= icn_data.len - tile_byte_size) : (tile_index += 1) {
        const tile_data_start = tile_index * tile_byte_size;
        const tile_data = icn_data[tile_data_start .. tile_data_start + tile_byte_size];

        // Determine the top-left (x, y) coordinate for the current tile.
        const tile_grid_x = tile_index % tiles_wide;
        const tile_grid_y = tile_index / tiles_wide;
        const base_x = tile_grid_x * 8;
        const base_y = tile_grid_y * 8;

        // Process each of the 8 rows in the tile.
        for (tile_data, 0..) |row_byte, y_in_tile| {
            // Process each of the 8 pixels in the row.
            var x_in_tile: u32 = 0;
            while (x_in_tile < 8) : (x_in_tile += 1) {
                // Check if the bit is set, starting from the most significant bit.
                if ((row_byte << @intCast(x_in_tile)) & 0x80 != 0) {
                    const px = base_x + x_in_tile;
                    const py = base_y + @as(u32, @intCast(y_in_tile));

                    // Ensure the pixel is within the defined buffer bounds.
                    if (px < width and py < height) {
                        const pixel_index = py * width + px;
                        data[pixel_index] = color;
                    }
                }
            }
        }
    }

    return .{
        .data = data,
        .width = width,
        .height = height,
    };
}

pub fn convertPngToIcn(arena: Allocator, png_filename: []const u8, icn_filename: []const u8) !void {
    var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    var image = try zigimg.Image.fromFilePath(arena, png_filename, &read_buffer);
    defer image.deinit(arena);

    // Ensure the image is in the correct 2-color palette format.
    if (image.pixels != .indexed1) {
        return error.InvalidPixelFormat;
    }

    // Assert that the image dimensions are tile-aligned (8x8).
    std.debug.assert(image.width % 8 == 0 and image.height % 8 == 0);

    var output_file = try std.fs.cwd().createFile(icn_filename, .{});
    defer output_file.close();

    const total_pixels = image.width * image.height;
    const buffer = try arena.alloc(u8, total_pixels / 8);
    @memset(buffer, 0);

    std.debug.assert(image.width % 8 == 0 and image.height % 8 == 0);

    for (0..image.height) |y| {
        for (0..image.width) |x| {
            const pixel = image.pixels.indexed1.indices[y * image.width + x];
            if (pixel == 1) {
                const tile_x = @divFloor(x, 8);
                const tile_y = @divFloor(y, 8);
                const tiles_per_row = image.width / 8;
                const tile_index = tile_y * tiles_per_row + tile_x;
                const row_in_tile = y % 8;
                const index = tile_index * 8 + row_in_tile;
                buffer[index] |= @as(u8, 1) << @intCast(7 - (x % 8));
            }
        }
    }

    try output_file.writeAll(buffer[0..]);
}

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

    var pixel_buffer = try toPixelBuffer(allocator, &icn_data, width, height, color);
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

    var pixel_buffer = try toPixelBuffer(allocator, icn_data, width, height, color);
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

    var pixel_buffer = try toPixelBuffer(allocator, icn_data, width, height, color);
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

    var pixel_buffer = try toPixelBuffer(allocator, &icn_data, width, height, color);
    defer pixel_buffer.deinit(allocator);

    // The first 8x8 area should be solid color
    try std.testing.expectEqual(color, pixel_buffer.data[0 * width + 0]);
    try std.testing.expectEqual(color, pixel_buffer.data[7 * width + 7]);

    // The area for the second tile should be transparent because the data was incomplete
    try std.testing.expectEqual(transparent, pixel_buffer.data[0 * width + 8]);
    try std.testing.expectEqual(transparent, pixel_buffer.data[7 * width + 15]);
}

const PixelBuffer = @import("root.zig").PixelBuffer;

const zigimg = @import("zigimg");

const std = @import("std");
const Allocator = std.mem.Allocator;
