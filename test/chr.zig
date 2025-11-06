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

    var pixel_buffer = try chrToPixelBuffer(u32, allocator, &chr_data, width, height, palette);
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

test "nmtToPixelBuffer 2x2 tiles" {
    const allocator = std.testing.allocator;

    // CHR data with 2 tiles
    const chr_data = [_]u8{
        // Tile 0 at address 0x00: Simple pattern
        0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, // ch1
        0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, // ch2
        // Tile 1 at address 0x10: All 1s in ch1
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // ch1
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ch2
    };

    // NMT data for 2x2 tiles (4 cells)
    const nmt_data = [_]u8{
        // Cell 0: tile 0, palette 0, no flip
        0x00, 0x00, 0x00,
        // Cell 1: tile 1, palette 1, no flip
        0x10, 0x00, 0x01,
        // Cell 2: tile 0, palette 2, flip_x
        0x00, 0x00, 0x12,
        // Cell 3: tile 1, palette 3, flip_y
        0x10, 0x00, 0x23,
    };

    // 64-color palette (16 palettes × 4 colors)
    var palette = [_]u32{0} ** 64;
    // Palette 0
    palette[0] = 0xff000000;
    palette[1] = 0xff111111;
    palette[2] = 0xff222222;
    palette[3] = 0xff333333;
    // Palette 1
    palette[4] = 0xff440000;
    palette[5] = 0xff551111;
    palette[6] = 0xff662222;
    palette[7] = 0xff773333;
    // Palette 2
    palette[8] = 0xff004400;
    palette[9] = 0xff115511;
    palette[10] = 0xff226622;
    palette[11] = 0xff337733;
    // Palette 3
    palette[12] = 0xff000044;
    palette[13] = 0xff111155;
    palette[14] = 0xff222266;
    palette[15] = 0xff333377;

    const width: u32 = 16;
    const height: u32 = 16;

    var pixel_buffer = try nmtToPixelBuffer(u32, allocator, &nmt_data, &chr_data, width, height, palette, 16);
    defer pixel_buffer.deinit(allocator);

    // Cell 0 (top-left): tile 0, palette 0
    // Row 0 of tile 0: ch1=0xff, ch2=0x00 → color index 1
    try expectEqual(palette[1], pixel_buffer.data[0 * width + 0]);
    try expectEqual(palette[1], pixel_buffer.data[0 * width + 7]);

    // Cell 1 (top-right): tile 1, palette 1
    // Row 0 of tile 1: ch1=0xff, ch2=0x00 → color index 1 from palette 1
    try expectEqual(palette[5], pixel_buffer.data[0 * width + 8]);

    // Cell 2 (bottom-left): tile 0, palette 2, flip_x
    // The flip should reverse the x-coordinate
    try expectEqual(palette[9], pixel_buffer.data[8 * width + 0]);

    // Cell 3 (bottom-right): tile 1, palette 3, flip_y
    try expectEqual(palette[13], pixel_buffer.data[8 * width + 8]);
}

test "nmtToChr copies and flips tiles" {
    const allocator = std.testing.allocator;

    // CHR data with 2 distinguishable tiles
    const chr_data = [_]u8{
        // Tile 0: diagonal pattern (top-left to bottom-right)
        0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01, // ch1
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ch2
        // Tile 1: horizontal stripes
        0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, // ch1
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ch2
    };

    // NMT data: 4 cells demonstrating different transformations
    const nmt_data = [_]u8{
        // Cell 0: tile 0, no flip
        0x00, 0x00, 0x00,
        // Cell 1: tile 0, flip_x
        0x00, 0x00, 0x10,
        // Cell 2: tile 1, flip_y
        0x10, 0x00, 0x20,
        // Cell 3: tile 1, flip_x and flip_y
        0x10, 0x00, 0x30,
    };

    const output = try nmtToChr(allocator, &nmt_data, &chr_data, 16);
    defer allocator.free(output);

    try expectEqual(64, output.len); // 4 tiles × 16 bytes

    // Cell 0: tile 0, no flip - should be identical
    try expectEqual(0x80, output[0]);
    try expectEqual(0x40, output[1]);
    try expectEqual(0x01, output[7]);

    // Cell 1: tile 0, flip_x - bits should be reversed in each byte
    try expectEqual(0x01, output[16]); // 0x80 reversed
    try expectEqual(0x02, output[17]); // 0x40 reversed
    try expectEqual(0x80, output[23]); // 0x01 reversed

    // Cell 2: tile 1, flip_y - rows should be reversed
    try expectEqual(0x00, output[32]); // Last row of source tile
    try expectEqual(0xff, output[33]); // Second-to-last row
    try expectEqual(0xff, output[39]); // First row of source tile

    // Cell 3: tile 1, flip_x and flip_y - both transformations
    try expectEqual(0x00, output[48]); // Last row, bits reversed
    try expectEqual(0xff, output[49]); // 0xff reversed is still 0xff
    try expectEqual(0xff, output[55]);
}

test "createIcnFromPng produces correct ICN output" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const png_path = "test/icn.png";
    const ref_icn_path = "test/icn.icn";
    const out_icn_path = "test/out.icn";

    try convertPngToIcn(allocator, png_path, out_icn_path);

    const ref_icn = try std.fs.cwd().readFileAlloc(allocator, ref_icn_path, 1024 * 1024);
    const out_icn = try std.fs.cwd().readFileAlloc(allocator, out_icn_path, 1024 * 1024);

    try std.testing.expectEqualSlices(u8, ref_icn, out_icn);

    defer std.fs.cwd().deleteFile(out_icn_path) catch {};
}

test "createChrFromPng produces correct CHR output" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const png_path = "test/chr.png";
    const ref_chr_path = "test/chr.chr";
    const out_chr_path = "test/out.chr";

    try convertPngToChr(allocator, png_path, out_chr_path);

    const ref_chr = try std.fs.cwd().readFileAlloc(allocator, ref_chr_path, 1024 * 1024);
    const out_chr = try std.fs.cwd().readFileAlloc(allocator, out_chr_path, 1024 * 1024);

    try std.testing.expectEqualSlices(u8, ref_chr, out_chr);
    defer std.fs.cwd().deleteFile(out_chr_path) catch {};
}

const chrz = @import("chrz");
const chrToPixelBuffer = chrz.chrToPixelBuffer;
const nmtToPixelBuffer = chrz.chrNmtToPixelBuffer;
const nmtToChr = chrz.chrNmtToChr;
const convertPngToChr = chrz.convertPngToChr;
const convertPngToIcn = chrz.convertPngToIcn;

const std = @import("std");
const expectEqual = std.testing.expectEqual;
