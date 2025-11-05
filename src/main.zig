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

    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    var options = flags.parse(args, "chrz", Options, .{});
    try options.setFormats();

    if (options.input_format == .png and options.output_format == .icn) {
        try chrz.convertPngToIcn(arena, options.positional.input, options.positional.output);
    } else if (options.input_format == .png and options.output_format == .chr) {
        try chrz.convertPngToChr(arena, options.positional.input, options.positional.output);
    } else if (options.input_format == .chr and options.output_format == .png) {
        try chrz.convertChrToPng(
            arena,
            options.positional.input,
            options.positional.output,
            .{
                .width = options.width,
                .height = options.height,
                .nmt = options.nmt,
                .nmt_addressing_mode = options.nmt_addressing_mode,
                .palette = options.palette,
                .palette_file = options.palette_file,
            },
        );
    } else if (options.input_format == .nmt and options.output_format == .chr) {
        const source_chr = options.source orelse return error.SourceChrRequired;
        try chrz.createChrFromNmt(
            arena,
            options.positional.input,
            options.positional.output,
            source_chr,
            options.nmt_addressing_mode orelse .direct,
        );
    } else {
        return error.UnsupportedConversion;
    }
}

pub const Options = struct {
    pub const description =
        \\Convert between indexed PNGs and CHR or ICN format based on file
        \\extension.
        \\
        \\Convert from CHR to a 4-bit indexed PNG:
        \\chr input.chr output.png
        \\
        \\Convert with custom palette:
        \\chr --palette e0f8d0,88c070,346856,081820 input.chr output.png
        \\
        \\Convert from 1-bit indexed PNG to ICN:
        \\chr input.png ouput.icn
        \\
        \\Convert from NMT to CHR (requires source CHR):
        \\chr --source sprites.chr map.nmt rendered.chr
        \\
        \\Convert from CHR+NMT to PNG with custom 64-color palette:
        \\chr --nmt map.nmt --palette-file colors.txt input.chr output.png
        \\
        \\Force input and output formats:
        \\chr -i chr -o png input.bin output
    ;

    pub const switches = .{
        .input_format = 'i',
        .output_format = 'o',
        .nmt = 'n',
        .nmt_addressing_mode = 'm',
        .source = 's',
        .palette = 'p',
    };

    pub const descriptions = .{
        .input_format = "format to convert from (chr, icn, nmt, or png)",
        .output_format = "format to convert to (chr, icn, or png)",
        .width = "width of input file",
        .height = "height of input file",
        .nmt = "use NMT tile map to create image",
        .nmt_addressing_mode = "how to read CHR data from NMT entry's address field",
        .source = "source CHR file (required for NMT to CHR conversion)",
        .palette = "4-color palette as comma-separated hex (e.g., e0f8d0,88c070,346856,081820)",
        .palette_file = "file containing palette colors (one hex color per line, 4 or 64 colors)",
    };

    input_format: ?Format = null,
    output_format: ?Format = null,
    width: ?u32 = null,
    height: ?u32 = null,
    nmt: ?[]const u8 = null,
    nmt_addressing_mode: ?AddressingMode = .direct,
    source: ?[]const u8 = null,
    palette: ?[]const u8 = null,
    palette_file: ?[]const u8 = null,

    positional: struct {
        pub const descriptions = .{
            .input = "Name of file to convert from.",
            .output = "Name of file to convert to.",
        };

        input: []const u8,
        output: []const u8,
    },

    pub const Format = enum {
        chr,
        icn,
        nmt,
        png,
    };

    pub fn setFormats(self: *@This()) !void {
        if (self.input_format == null)
            self.input_format =
                if (std.mem.endsWith(u8, self.positional.input, "png"))
                    .png
                else if (std.mem.endsWith(u8, self.positional.input, "icn"))
                    .icn
                else if (std.mem.endsWith(u8, self.positional.input, "nmt"))
                    .nmt
                else if (std.mem.endsWith(u8, self.positional.input, "chr"))
                    .chr
                else
                    return error.UnknownFormat;

        if (self.output_format == null)
            self.output_format =
                if (std.mem.endsWith(u8, self.positional.output, "png"))
                    .png
                else if (std.mem.endsWith(u8, self.positional.output, "icn"))
                    .icn
                else if (std.mem.endsWith(u8, self.positional.output, "nmt"))
                    .nmt
                else if (std.mem.endsWith(u8, self.positional.output, "chr"))
                    .chr
                else
                    return error.UnknownFormat;
    }
};

test "Options.setFormats sets formats based on string suffix" {
    const options_with_suffixes: Options = .{
        .positional = .{
            .input = "test.png",
            .output = "test.icn",
        },
    };

    try expectEqual(.png, options_with_suffixes.input_format);
    try expectEqual(.icn, options_with_suffixes.output_format);
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);

    std.process.exit(1);
}

const chrz = @import("chrz");
const AddressingMode = chrz.AddressingMode;

const flags = @import("flags");

const std = @import("std");
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
