{
  callPackage,
  elfkickers,
  lib,
  stdenv,
  zig,
}:
stdenv.mkDerivation (
  finalAttrs: {
    name = "chrz";
    version = "0.7.0";
    src = lib.cleanSource ./.;

    nativeBuildInputs =
      [
        zig
      ]
      ++ lib.optionals stdenv.isLinux [elfkickers];

    deps = callPackage ./build.zig.zon.nix {name = "${finalAttrs.name}-${finalAttrs.version}";};

    zigBuildFlags = [
      "--system"
      "${finalAttrs.deps}"
      "-Doptimize=ReleaseSmall"
    ];

    meta = {
      mainProgram = "chrz";
      license = lib.licenses.mit;
    };
  }
)
