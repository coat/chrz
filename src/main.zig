pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    var args_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, arena);
    _ = args_iter.skip();

    var options = parseArgs(&args_iter, io);
    try options.setFormats();

    const input = options.input.?;
    const output = options.output.?;

    if (options.input_format == .png and options.output_format == .icn) {
        try chrz.convertPngToIcn(arena, io, input, output);
    } else if (options.input_format == .png and options.output_format == .chr) {
        try chrz.convertPngToChr(arena, io, input, output);
    } else if (options.input_format == .chr and options.output_format == .png) {
        try chrz.convertChrToPng(
            arena,
            io,
            input,
            output,
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
            io,
            input,
            output,
            source_chr,
            options.nmt_addressing_mode orelse .direct,
        );
    } else {
        return error.UnsupportedConversion;
    }
}

fn parseArgs(args: *std.process.Args.Iterator, io: std.Io) Options {
    var options: Options = .{};

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            std.Io.File.writeStreamingAll(.stdout(), io, usage) catch {};
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--input-format")) {
            const val = args.next() orelse fatal("missing value for '{s}'", .{arg});
            options.input_format = std.meta.stringToEnum(Options.Format, val) orelse
                fatal("invalid format: '{s}'", .{val});
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output-format")) {
            const val = args.next() orelse fatal("missing value for '{s}'", .{arg});
            options.output_format = std.meta.stringToEnum(Options.Format, val) orelse
                fatal("invalid format: '{s}'", .{val});
        } else if (std.mem.eql(u8, arg, "--width")) {
            const val = args.next() orelse fatal("missing value for '--width'", .{});
            options.width = std.fmt.parseInt(u32, val, 10) catch
                fatal("invalid width: '{s}'", .{val});
        } else if (std.mem.eql(u8, arg, "--height")) {
            const val = args.next() orelse fatal("missing value for '--height'", .{});
            options.height = std.fmt.parseInt(u32, val, 10) catch
                fatal("invalid height: '{s}'", .{val});
        } else if (std.mem.eql(u8, arg, "-n") or std.mem.eql(u8, arg, "--nmt")) {
            options.nmt = args.next() orelse fatal("missing value for '{s}'", .{arg});
        } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--nmt-addressing-mode")) {
            const val = args.next() orelse fatal("missing value for '{s}'", .{arg});
            options.nmt_addressing_mode = std.meta.stringToEnum(AddressingMode, val) orelse
                fatal("invalid addressing mode: '{s}'", .{val});
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--source")) {
            options.source = args.next() orelse fatal("missing value for '{s}'", .{arg});
        } else if (std.mem.eql(u8, arg, "-p") or std.mem.eql(u8, arg, "--palette")) {
            options.palette = args.next() orelse fatal("missing value for '{s}'", .{arg});
        } else if (std.mem.eql(u8, arg, "--palette-file")) {
            options.palette_file = args.next() orelse fatal("missing value for '--palette-file'", .{});
        } else if (arg.len > 0 and arg[0] == '-') {
            fatal("unknown option: '{s}'", .{arg});
        } else {
            if (options.input == null) {
                options.input = arg;
            } else if (options.output == null) {
                options.output = arg;
            } else {
                fatal("unexpected argument: '{s}'", .{arg});
            }
        }
    }

    if (options.input == null or options.output == null) {
        std.Io.File.writeStreamingAll(.stderr(), io, usage) catch {};
        std.process.exit(1);
    }

    return options;
}

const usage =
    \\Usage: chrz [options] <input> <output>
    \\
    \\Convert between indexed PNGs and CHR or ICN format based on file
    \\extension.
    \\
    \\Convert from CHR to a 4-bit indexed PNG:
    \\  chrz input.chr output.png
    \\
    \\Convert with custom palette:
    \\  chrz --palette e0f8d0,88c070,346856,081820 input.chr output.png
    \\
    \\Convert from 1-bit indexed PNG to ICN:
    \\  chrz input.png output.icn
    \\
    \\Convert from NMT to CHR (requires source CHR):
    \\  chrz --source sprites.chr map.nmt rendered.chr
    \\
    \\Convert from CHR+NMT to PNG with custom 64-color palette:
    \\  chrz --nmt map.nmt --palette-file colors.txt input.chr output.png
    \\
    \\Force input and output formats:
    \\  chrz -i chr -o png input.bin output
    \\
    \\Options:
    \\  -i, --input-format <fmt>        format to convert from (chr, icn, nmt, or png)
    \\  -o, --output-format <fmt>       format to convert to (chr, icn, or png)
    \\  --width <n>                     width of input file
    \\  --height <n>                    height of input file
    \\  -n, --nmt <file>                use NMT tile map to create image
    \\  -m, --nmt-addressing-mode <m>   how to read CHR data from NMT entry's address field
    \\  -s, --source <file>             source CHR file (required for NMT to CHR conversion)
    \\  -p, --palette <colors>          4-color palette as comma-separated hex (e.g., e0f8d0,88c070,346856,081820)
    \\  --palette-file <file>           file containing palette colors (one hex color per line, 4 or 64 colors)
    \\  -h, --help                      show this help and exit
    \\
    \\Arguments:
    \\  <input>   Name of file to convert from.
    \\  <output>  Name of file to convert to.
    \\
;

pub const Options = struct {
    input_format: ?Format = null,
    output_format: ?Format = null,
    width: ?u32 = null,
    height: ?u32 = null,
    nmt: ?[]const u8 = null,
    nmt_addressing_mode: ?AddressingMode = .direct,
    source: ?[]const u8 = null,
    palette: ?[]const u8 = null,
    palette_file: ?[]const u8 = null,
    input: ?[]const u8 = null,
    output: ?[]const u8 = null,

    pub const Format = enum {
        chr,
        icn,
        nmt,
        png,
    };

    pub fn setFormats(self: *@This()) !void {
        const input = self.input orelse return error.MissingInput;
        const output = self.output orelse return error.MissingOutput;

        if (self.input_format == null)
            self.input_format =
                if (std.mem.endsWith(u8, input, "png"))
                    .png
                else if (std.mem.endsWith(u8, input, "icn"))
                    .icn
                else if (std.mem.endsWith(u8, input, "nmt"))
                    .nmt
                else if (std.mem.endsWith(u8, input, "chr"))
                    .chr
                else
                    return error.UnknownFormat;

        if (self.output_format == null)
            self.output_format =
                if (std.mem.endsWith(u8, output, "png"))
                    .png
                else if (std.mem.endsWith(u8, output, "icn"))
                    .icn
                else if (std.mem.endsWith(u8, output, "nmt"))
                    .nmt
                else if (std.mem.endsWith(u8, output, "chr"))
                    .chr
                else
                    return error.UnknownFormat;
    }
};

test "Options.setFormats sets formats based on string suffix" {
    var options: Options = .{
        .input = "test.png",
        .output = "test.icn",
    };

    try options.setFormats();

    try expectEqual(.png, options.input_format);
    try expectEqual(.icn, options.output_format);
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}

const chrz = @import("chrz");
const AddressingMode = chrz.AddressingMode;

const std = @import("std");
const expectEqual = std.testing.expectEqual;
