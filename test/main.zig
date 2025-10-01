const createChrFromPng = @import("main").createChrFromPng;
const createIcnFromPng = @import("main").createIcnFromPng;
const Flags = @import("main").Flags;

const std = @import("std");

test "createIcnFromPng produces correct ICN output" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const png_path = "test/icn.png";
    const ref_icn_path = "test/icn.icn";
    const out_icn_path = "test/out.icn";

    const options: Flags = .{
        .format = .icn,
        .output = out_icn_path,
        .positional = .{ .file = png_path },
    };

    try createIcnFromPng(allocator, options);

    const ref_icn = try std.fs.cwd().readFileAlloc(allocator, ref_icn_path, 1024 * 1024);
    const out_icn = try std.fs.cwd().readFileAlloc(allocator, out_icn_path, 1024 * 1024);

    try std.testing.expectEqualSlices(u8, ref_icn, out_icn);

    defer std.fs.cwd().deleteFile(out_icn_path) catch {};
}

test "createChrFromPng produces correct CHR output" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const png_path = "test/chr.png"; // You need to provide this PNG
    const ref_chr_path = "test/chr.chr";
    const out_chr_path = "test/out.chr";

    const options: Flags = .{
        .format = .chr,
        .output = out_chr_path,
        .positional = .{ .file = png_path },
    };

    try createChrFromPng(allocator, options);

    const ref_chr = try std.fs.cwd().readFileAlloc(allocator, ref_chr_path, 1024 * 1024);
    const out_chr = try std.fs.cwd().readFileAlloc(allocator, out_chr_path, 1024 * 1024);

    try std.testing.expectEqualSlices(u8, ref_chr, out_chr);
    defer std.fs.cwd().deleteFile(out_chr_path) catch {};
}
