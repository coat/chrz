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

/// Generates CHR data from NMT (nametable) data and source CHR.
///
/// Creates a new CHR buffer by copying and transforming tiles from the source
/// CHR according to the NMT layout. Each NMT entry specifies which tile to
/// copy and whether to flip it horizontally or vertically.
///
/// Parameters:
/// - allocator: The memory allocator to use for the CHR buffer.
/// - nmt_data: A slice of bytes representing the NMT file data.
/// - chr_data: The source CHR spritesheet data to copy tiles from.
/// - offset: Multiplier for address (16 for direct byte offset, 1 for tile index).
///
/// Returns:
/// A slice of bytes containing the generated CHR data.
pub fn nmtToChr(
    allocator: std.mem.Allocator,
    nmt_data: []const u8,
    chr_data: []const u8,
    offset: u8,
) ![]u8 {
    const cell_size = 3;
    const tile_byte_size = 16;
    const num_cells = nmt_data.len / cell_size;

    const output = try allocator.alloc(u8, num_cells * tile_byte_size);
    @memset(output, 0);

    var cell_index: u32 = 0;
    while (cell_index < num_cells) : (cell_index += 1) {
        const cell_start = cell_index * cell_size;
        const cell = nmt_data[cell_start..][0..cell_size];

        var address: usize = @intCast(std.mem.readInt(u16, cell[0..2], .little));
        if (offset != 16) {
            address = address * 16;
        }
        const sprite = @as(Sprite, @bitCast(cell[2]));

        const tile_data_start = address;
        if (tile_data_start + 16 > chr_data.len) continue;

        const src_ch1 = chr_data[tile_data_start..][0..8];
        const src_ch2 = chr_data[tile_data_start + 8 ..][0..8];

        const dst_start = cell_index * tile_byte_size;
        const dst_ch1 = output[dst_start..][0..8];
        const dst_ch2 = output[dst_start + 8 ..][0..8];

        for (0..8) |row| {
            const src_row = if (sprite.flip_y) 7 - row else row;
            const ch1_byte = src_ch1[src_row];
            const ch2_byte = src_ch2[src_row];

            dst_ch1[row] = if (sprite.flip_x) @bitReverse(ch1_byte) else ch1_byte;
            dst_ch2[row] = if (sprite.flip_x) @bitReverse(ch2_byte) else ch2_byte;
        }
    }

    return output;
}

/// Generates a 32-bit pixel buffer from NMT (nametable) data.
///
/// NMT data consists of cells that reference sprites in a CHR spritesheet.
/// Each cell is 3 bytes: 2-byte address + 1-byte Sprite metadata.
///
/// Parameters:
/// - allocator: The memory allocator to use for the pixel buffer.
/// - nmt_data: A slice of bytes representing the NMT file data.
/// - chr_data: The CHR spritesheet data to reference.
/// - width: The width of the target pixel buffer.
/// - height: The height of the target pixel buffer.
/// - palette: An array of 64 u32 ARGB colors (16 palettes × 4 colors).
///
/// Returns:
/// A `PixelBuffer` containing the generated pixel data.
pub fn nmtToPixelBuffer(
    allocator: std.mem.Allocator,
    nmt_data: []const u8,
    chr_data: []const u8,
    width: u32,
    height: u32,
    palette: [64]u32,
    offset: u8,
) !PixelBuffer {
    const pixel_count = width * height;
    const data = try allocator.alloc(u32, pixel_count);
    @memset(data, palette[0]);

    const tiles_wide = width / 8;
    const cell_size = 3;

    var cell_index: u32 = 0;
    while (cell_index * cell_size + cell_size <= nmt_data.len) : (cell_index += 1) {
        const cell_start = cell_index * cell_size;
        const cell = nmt_data[cell_start..][0..cell_size];

        var address: usize = @intCast(std.mem.readInt(u16, cell[0..2], .little));
        if (offset != 16) {
            address = address * 16;
            // std.debug.print("after ddress: {d}\n", .{address});
        }
        const sprite = @as(Sprite, @bitCast(cell[2]));

        const tile_data_start = address;
        if (tile_data_start + 16 > chr_data.len) continue;

        const ch1_data = chr_data[tile_data_start..][0..8];
        const ch2_data = chr_data[tile_data_start + 8 ..][0..8];

        const tile_grid_x = cell_index % tiles_wide;
        const tile_grid_y = cell_index / tiles_wide;
        const base_x = tile_grid_x * 8;
        const base_y = tile_grid_y * 8;

        var y_in_tile: u32 = 0;
        while (y_in_tile < 8) : (y_in_tile += 1) {
            const y = if (sprite.flip_y) 7 - y_in_tile else y_in_tile;
            const row_byte_ch1 = ch1_data[y];
            const row_byte_ch2 = ch2_data[y];

            var x_in_tile: u32 = 0;
            while (x_in_tile < 8) : (x_in_tile += 1) {
                const x = if (sprite.flip_x) 7 - x_in_tile else x_in_tile;
                const bit1 = @intFromBool((row_byte_ch1 << @intCast(x)) & 0x80 != 0);
                const bit2 = @intFromBool((row_byte_ch2 << @intCast(x)) & 0x80 != 0);
                const color_index: u2 = (@as(u2, bit2) << 1) | bit1;

                const palette_offset: usize = @as(usize, sprite.palette) * 4;
                const color = palette[palette_offset + color_index];

                const px = base_x + x_in_tile;
                const py = base_y + y_in_tile;

                if (px < width and py < height) {
                    data[py * width + px] = color;
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

/// Converts a zigimg.Image with indexed2 (4-color) pixel storage into
/// a CHR byte slice.
///
/// The function assumes the image dimensions are a multiple of 8.
pub fn convertPngToChr(arena: Allocator, input_filename: []const u8, output_filename: []const u8) !void {
    const read_buffer = arena.alloc(u8, 1024 * 1024) catch @panic("OOM");
    var image = try zigimg.Image.fromFilePath(arena, input_filename, read_buffer);
    defer image.deinit(arena);

    if (image.pixels != .indexed2) {
        return error.InvalidPixelFormat;
    }

    std.debug.assert(image.width % 8 == 0 and image.height % 8 == 0);

    var output_file = try std.fs.cwd().createFile(output_filename, .{});
    defer output_file.close();

    const total_pixels = image.width * image.height;
    // Each pixel is 2 bits. 8 pixels per byte, 2 planes. 2/8 = 1/4 byte per pixel.
    const buffer_size = total_pixels / 4;
    const buffer = try arena.alloc(u8, buffer_size);
    @memset(buffer, 0);

    const tiles_per_row = image.width / 8;
    const tile_byte_size = 16; // 16 bytes per CHR tile

    for (0..image.height) |y| {
        for (0..image.width) |x| {
            // Get the 2-bit palette index (0, 1, 2, or 3) for the current pixel.
            const palette_index = image.pixels.indexed2.indices[y * image.width + x];

            // bit1 is the least significant bit (LSB).
            const bit1 = palette_index & 1;
            // bit2 is the most significant bit (MSB).
            const bit2 = (palette_index >> 1) & 1;

            // Calculate which tile this pixel belongs to.
            const tile_x = @divFloor(x, 8);
            const tile_y = @divFloor(y, 8);
            const tile_index = tile_y * tiles_per_row + tile_x;

            // Calculate the position of the pixel within its 8x8 tile.
            const row_in_tile = y % 8;
            const col_in_tile = x % 8;

            // The bit position within the byte (7 is MSB, 0 is LSB).
            const bit_position = 7 - col_in_tile;

            // Calculate the base index for the current tile in the output buffer.
            const tile_base_index = tile_index * tile_byte_size;

            // If bit1 is set, write a '1' to the corresponding position in the first bitplane.
            if (bit1 != 0) {
                const index_ch1 = tile_base_index + row_in_tile;
                buffer[index_ch1] |= (@as(u8, 1) << @intCast(bit_position));
            }

            // If bit2 is set, write a '1' to the corresponding position in the second bitplane.
            // The second bitplane starts 8 bytes after the first one.
            if (bit2 != 0) {
                const index_ch2 = tile_base_index + 8 + row_in_tile;
                buffer[index_ch2] |= (@as(u8, 1) << @intCast(bit_position));
            }
        }
    }

    try output_file.writeAll(buffer[0..]);
}

fn parseHexColor(hex_str: []const u8) !Rgba32 {
    // Remove leading '#' if present
    const hex = if (hex_str.len > 0 and hex_str[0] == '#') hex_str[1..] else hex_str;

    // Parse RGB (6 chars) or RGBA (8 chars)
    const r = try std.fmt.parseInt(u8, hex[0..2], 16);
    const g = try std.fmt.parseInt(u8, hex[2..4], 16);
    const b = try std.fmt.parseInt(u8, hex[4..6], 16);
    const a: u8 = if (hex.len >= 8) try std.fmt.parseInt(u8, hex[6..8], 16) else 0xff;

    return .{ .r = r, .g = g, .b = b, .a = a };
}

/// caller owns slice
fn parsePalette(allocator: Allocator, palette_str: []const u8) ![]Rgba32 {
    var palette = try allocator.alloc(Rgba32, 4);
    @memcpy(palette, &default_palette);

    var iter = std.mem.splitScalar(u8, palette_str, ',');
    var i: usize = 0;

    while (iter.next()) |color_str| : (i += 1) {
        if (i >= 4) return error.TooManyColors;

        const trimmed = std.mem.trim(u8, color_str, &std.ascii.whitespace);
        if (trimmed.len == 0) continue;

        palette[i] = try parseHexColor(trimmed);
    }

    return palette;
}

/// caller owns slice
fn parsePaletteFile(allocator: Allocator, filepath: []const u8) ![]Rgba32 {
    var file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, std.math.maxInt(u32));

    var colors = std.ArrayList(Rgba32).empty;
    defer colors.deinit(allocator);

    var line_iter = std.mem.splitScalar(u8, file_content, '\n');
    while (line_iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue; // Skip empty lines
        if (trimmed[0] == '#' and trimmed.len > 1 and !std.ascii.isHex(trimmed[1])) continue; // Skip comment lines

        const color = try parseHexColor(trimmed);
        try colors.append(allocator, color);
    }

    if (colors.items.len != 4 and colors.items.len != 64) {
        return error.InvalidPaletteLength;
    }

    return colors.toOwnedSlice(allocator);
}

var default_palette: [4]Rgba32 = .{
    .{ .r = 0xe0, .g = 0xf8, .b = 0xd0 },
    .{ .r = 0x88, .g = 0xc0, .b = 0x70 },
    .{ .r = 0x34, .g = 0x68, .b = 0x56 },
    .{ .r = 0x08, .g = 0x18, .b = 0x20 },
};

const default_nmt_palette: [64]u32 = .{
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
    0xffe0f8d0, 0xff88c070, 0xff346856, 0xff081820,
};

pub fn createChrFromNmt(
    arena: Allocator,
    nmt_input: []const u8,
    chr_filename: []const u8,
    source_chr: []const u8,
    addressing_mode: AddressingMode,
) !void {
    var nmt_file = try std.fs.cwd().openFile(nmt_input, .{});
    defer nmt_file.close();

    const nmt_data = try nmt_file.readToEndAlloc(arena, std.math.maxInt(u32));

    var chr_file = try std.fs.cwd().openFile(source_chr, .{});
    defer chr_file.close();

    const chr_data = try chr_file.readToEndAlloc(arena, std.math.maxInt(u32));

    const output_chr = try chrz.chrNmtToChr(
        arena,
        nmt_data,
        chr_data,
        if (addressing_mode == .indexed) 1 else 16,
    );

    var output_file = try std.fs.cwd().createFile(chr_filename, .{});
    defer output_file.close();

    try output_file.writeAll(output_chr);
}

pub const ChrOptions = struct {
    width: ?u32 = null,
    height: ?u32 = null,
    nmt: ?[]const u8 = null,
    nmt_addressing_mode: ?AddressingMode = .direct,
    nmt_source_chr: ?[]const u8 = null,
    palette: ?[]const u8 = null,
    palette_file: ?[]const u8 = null,
};

pub fn convertChrToPng(arena: Allocator, chr_input: []const u8, output_filename: []const u8, options: ChrOptions) !void {
    var chr_file = try std.fs.cwd().openFile(chr_input, .{});
    defer chr_file.close();

    const chr_data = try chr_file.readToEndAlloc(arena, std.math.maxInt(u32));

    var width: u32 = 0;
    var height: u32 = 0;

    if (options.width != null or options.height != null) {
        width = options.width orelse return error.WidthRequired;
        height = options.height orelse return error.HeightRequired;
    } else {
        const num_tiles = chr_data.len / 16;
        const tiles_per_side = std.math.sqrt(num_tiles);

        std.debug.assert(tiles_per_side * tiles_per_side == num_tiles);

        width = tiles_per_side * 8;
        height = tiles_per_side * 8;
    }

    const chr = create_chr: {
        if (options.nmt) |nmt_path| {
            var nmt_file = try std.fs.cwd().openFile(nmt_path, .{});
            defer nmt_file.close();

            const nmt_data = try nmt_file.readToEndAlloc(arena, std.math.maxInt(u32));

            const nmt_palette = nmt_pal: {
                if (options.palette_file) |palette_file| {
                    const rgba_palette = try parsePaletteFile(arena, palette_file);
                    var pal: [64]u32 = undefined;
                    for (rgba_palette, 0..) |pixel, i| {
                        pal[i] = pixel.to.u32Rgba();
                    }
                    break :nmt_pal pal;
                } else {
                    break :nmt_pal default_nmt_palette;
                }
            };

            break :create_chr try nmtToPixelBuffer(
                arena,
                nmt_data,
                chr_data,
                width,
                height,
                nmt_palette,
                if (options.nmt_addressing_mode.? == .indexed) 1 else 16,
            );
        } else {
            break :create_chr try toPixelBuffer(
                arena,
                chr_data,
                width,
                height,
                .{ 0, 1, 2, 3 },
            );
        }
    };

    var image: zigimg.Image = undefined;
    if (options.nmt) |_| {
        image = try zigimg.Image.create(arena, width, height, .rgba32);
        for (chr.data, 0..) |pixel, i| {
            image.pixels.rgba32[i] = zigimg.color.Rgba32.from.u32Rgba(pixel);
        }
    } else {
        image = try zigimg.Image.create(arena, width, height, .indexed2);

        const palette = if (options.palette_file) |palette_file|
            try parsePaletteFile(arena, palette_file)
        else if (options.palette) |palette_str|
            try parsePalette(arena, palette_str)
        else
            &default_palette;

        image.pixels.indexed2.palette = palette;

        for (chr.data, 0..) |pixel, i| {
            image.pixels.indexed2.indices[i] = @truncate(pixel % 4);
        }
    }
    defer image.deinit(arena);

    var write_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    try image.writeToFilePath(arena, output_filename, write_buffer[0..], .{ .png = .{} });
}

const chrz = @import("root.zig");
const AddressingMode = chrz.AddressingMode;
const PixelBuffer = chrz.PixelBuffer;
const Sprite = chrz.Sprite;
const Nmt = chrz.Nmt;

const zigimg = @import("zigimg");
const Rgba32 = zigimg.color.Rgba32;

const std = @import("std");
const Allocator = std.mem.Allocator;
