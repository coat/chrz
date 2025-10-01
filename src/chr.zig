/// Generates a 32-bit pixel buffer from 2-bit CHR data.
///
/// CHR data is organized in 8x8 tiles. Each tile consists of 16 bytes.
/// The first 8 bytes are the first bitplane (least significant bit of the color index).
/// The next 8 bytes are the second bitplane (most significant bit of the color index).
///
/// Parameters:
/// - allocator: The memory allocator to use for the pixel buffer.
/// - chr_data: A slice of bytes representing the CHR file data.
/// - width: The width of the target pixel buffer.
/// - height: The height of the target pixel buffer.
/// - palette: An array of four u32 ARGB colors to map the 2-bit indices to.
///
/// Returns:
/// A `PixelBuffer` containing the generated pixel data, or an error if
/// memory allocation fails.
pub fn toPixelBuffer(
    allocator: std.mem.Allocator,
    chr_data: []const u8,
    width: u32,
    height: u32,
    palette: [4]u32,
) !PixelBuffer {
    const pixel_count = width * height;
    const data = try allocator.alloc(u32, pixel_count);

    // Initialize the buffer with the background color (palette index 0).
    // std.mem.set(u32, data, palette[0]);
    @memset(data, palette[0]);

    const tiles_wide = width / 8;
    const tile_byte_size = 16; // 8 bytes for ch1 + 8 bytes for ch2

    // Iterate over each 16-byte tile in the input data.
    var tile_index: u32 = 0;
    while (tile_index * tile_byte_size <= chr_data.len - tile_byte_size) : (tile_index += 1) {
        const tile_data_start = tile_index * tile_byte_size;
        const tile_data = chr_data[tile_data_start .. tile_data_start + tile_byte_size];

        // The first 8 bytes are the first bitplane (ch1)
        const ch1_data = tile_data[0..8];
        // The next 8 bytes are the second bitplane (ch2)
        const ch2_data = tile_data[8..16];

        // Determine the top-left (x, y) coordinate for the current tile.
        const tile_grid_x = tile_index % tiles_wide;
        const tile_grid_y = tile_index / tiles_wide;
        const base_x = tile_grid_x * 8;
        const base_y = tile_grid_y * 8;

        // Process each of the 8 rows in the tile.
        var y_in_tile: u32 = 0;
        while (y_in_tile < 8) : (y_in_tile += 1) {
            const row_byte_ch1 = ch1_data[y_in_tile];
            const row_byte_ch2 = ch2_data[y_in_tile];

            // Process each of the 8 pixels in the row.
            var x_in_tile: u32 = 0;
            while (x_in_tile < 8) : (x_in_tile += 1) {
                // Get the bit from the first channel (LSB of the color index)
                const bit1 = @intFromBool((row_byte_ch1 << @intCast(x_in_tile)) & 0x80 != 0);
                // Get the bit from the second channel (MSB of the color index)
                const bit2 = @intFromBool((row_byte_ch2 << @intCast(x_in_tile)) & 0x80 != 0);

                // Combine the bits to form the 2-bit palette index (0-3).
                const palette_index = (@as(u2, bit2) << 1) | bit1;

                // Only write pixels that are not the background color, since the
                // buffer is already pre-filled. This is a small optimization.
                if (palette_index != 0) {
                    const px = base_x + x_in_tile;
                    const py = base_y + y_in_tile;

                    // Ensure the pixel is within the defined buffer bounds.
                    if (px < width and py < height) {
                        const pixel_index = py * width + px;
                        data[pixel_index] = palette[palette_index];
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

const PixelBuffer = @import("root.zig").PixelBuffer;

const std = @import("std");
