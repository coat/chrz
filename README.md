# chrz

A Zig library that can read [ICN](https://wiki.xxiivv.com/site/icn_format.html)
and [CHR](https://wiki.xxiivv.com/site/chr_format.html) data and convert them
to 32-bit pixel buffers, suitable for rendering as an image in other graphics
libraries, like SDL for example.

Also includes a small command line tool to convert indexed PNGs to CHR and ICN
files, for use in an asset pipeline.

## Usage

### Zig

```zig
const chrz = @import("chrz");

const pixels = try chrz.chrToPixelBuffer(
    allocator,
    @embedFile("image.chr"),
    10,
    10,
    .{ 0xff765440, 0xff698da9, 0xffc6c6ca, 0xfff1f1f1 },
);
defer allocator.free(pixels);

std.debug.print("Image size: {d}x{d}\n", .{pixels.width, pixels.height});
std.debug.print("Pixels: {d}\n", .{pixels.data.len});
```

#### Getting Started

To import chrz in your project, run the following command:

```bash
zig fetch --save git+https://github.com/coat/chrz
```

Then set add the dependency in your `build.zig`:

```zig
const chrz_mod = b.dependency("chrz", .{
    .target = target,
    .optimize = optimize,
}).module("chrz")

mod.root_module.addImport("chrz", chrz_mod);
```

### CLI

Convert a 4-color (2-bit) indexed PNG `foo.png` to a CHR file called `foo.chr`:

```bash
chrz foo.png
```

Convert a 2-color (1-bit) indexed PNG `foo.png` to an ICN file called `foo10x10.icn`:

```bash
chrz -f icn -o foo10x10.icn foo.png
```

Run `chrz -h` for more help.

#### Installation

Download the latest release from
[GitHub](https://github.com/coat/chrz/releases) and place the binary in your
PATH.

##### Nix

`nix run github:coat/chrz`

## Acknowledgements

The [File Formats article](https://wiki.xxiivv.com/site/file_formats.html) on
the [xxiivv wiki](https://wiki.xxiivv.com/site/home.html) which is a great
source of documentation and code snippets.
