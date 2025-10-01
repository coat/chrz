pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const gpa, const is_debug = gpa: {
        if (builtin.os.tag == .emscripten) break :gpa .{ std.heap.c_allocator, false };
        if (builtin.os.tag == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);

    const options = flags.parse(args, "chrz", Flags, .{});

    switch (options.format) {
        .icn => try createIcnFromPng(allocator, options),
        .chr => try createChrFromPng(allocator, options),
    }
}

pub fn createIcnFromPng(arena: Allocator, options: Flags) !void {
    const filename = options.positional.file;

    const read_buffer = arena.alloc(u8, 1024 * 1024) catch @panic("OOM");
    var image = try zigimg.Image.fromFilePath(arena, filename, read_buffer);
    defer image.deinit(arena);

    // Ensure the image is in the correct 2-color palette format.
    if (image.pixels != .indexed1) {
        return error.InvalidPixelFormat;
    }

    // Assert that the image dimensions are tile-aligned (8x8).
    std.debug.assert(image.width % 8 == 0 and image.height % 8 == 0);

    const output_filename = if (options.output) |out| out else blk: {
        const ext = ".png";
        const base_len = if (std.mem.endsWith(u8, filename, ext)) filename.len - ext.len else filename.len;
        break :blk std.fmt.allocPrint(arena, "{s}.icn", .{filename[0..base_len]}) catch @panic("OOM");
    };

    var output_file = std.fs.cwd().createFile(output_filename, .{}) catch |err| {
        fatal("unable to open '{s}' for writing: {s}", .{ output_filename, @errorName(err) });
    };
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

    output_file.writeAll(buffer[0..]) catch |err| {
        fatal("unable to write to '{s}': {s}", .{ output_filename, @errorName(err) });
    };
}

/// Converts a zigimg.Image with indexed2 (4-color) pixel storage into
/// a CHR byte slice.
///
/// The function assumes the image dimensions are a multiple of 8.
pub fn createChrFromPng(arena: Allocator, options: Flags) !void {
    const filename = options.positional.file;

    const read_buffer = arena.alloc(u8, 1024 * 1024) catch @panic("OOM");
    var image = try zigimg.Image.fromFilePath(arena, filename, read_buffer);
    defer image.deinit(arena);
    // Ensure the image is in the correct 4-color palette format.
    if (image.pixels != .indexed2) {
        return error.InvalidPixelFormat;
    }

    // Assert that the image dimensions are tile-aligned (8x8).
    std.debug.assert(image.width % 8 == 0 and image.height % 8 == 0);

    const output_filename = if (options.output) |out| out else blk: {
        const ext = ".png";
        const base_len = if (std.mem.endsWith(u8, filename, ext)) filename.len - ext.len else filename.len;
        break :blk std.fmt.allocPrint(arena, "{s}.chr", .{filename[0..base_len]}) catch @panic("OOM");
    };

    var output_file = std.fs.cwd().createFile(output_filename, .{}) catch |err| {
        fatal("unable to open '{s}' for writing: {s}", .{ output_filename, @errorName(err) });
    };
    defer output_file.close();

    const total_pixels = image.width * image.height;
    // Each pixel is 2 bits. 8 pixels per byte, 2 planes. 2/8 = 1/4 byte per pixel.
    const buffer_size = total_pixels / 4;
    const buffer = try arena.alloc(u8, buffer_size);
    @memset(buffer, 0);

    const tiles_per_row = image.width / 8;
    const tile_byte_size = 16; // 16 bytes per CHR tile

    // Iterate over every pixel of the source image.
    for (0..image.height) |y| {
        for (0..image.width) |x| {
            // Get the 2-bit palette index (0, 1, 2, or 3) for the current pixel.
            const palette_index = image.pixels.indexed2.indices[y * image.width + x];

            // Deconstruct the palette index into two separate bits.
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

    output_file.writeAll(buffer[0..]) catch |err| {
        fatal("unable to write to '{s}': {s}", .{ output_filename, @errorName(err) });
    };
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);

    std.process.exit(1);
}

pub const Flags = struct {
    pub const description =
        \\Convert an indexed PNG to CHR or ICN format.
    ;

    pub const switches = .{
        .format = 'f',
        .output = 'o',
    };

    pub const descriptions = .{
        .format = "format to convert to (chr or icn), default is chr",
        .output = "Name of output file, default is input name with appropriate extension",
    };

    format: enum {
        pub const descriptions = .{
            .chr = "Output CHR format",
            .icn = "Output ICN format",
        };

        chr,
        icn,
    } = .chr,
    output: ?[]const u8 = null,

    positional: struct {
        pub const descriptions = .{
            .file = "Input file. Must be a PNG file with indexed colors.",
        };

        file: []const u8,
    },
};

const chrz = @import("chrz");

const flags = @import("flags");
const zigimg = @import("zigimg");

const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
