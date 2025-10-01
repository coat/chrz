{
  callPackage,
  lib,
  stdenvNoCC,
  makeWrapper,
  zig_0_15,
}: let
  zig_hook = zig_0_15.hook.overrideAttrs {
    zig_default_flags = "-Dcpu=baseline -Doptimize=ReleaseSmall --color off";
  };
in
  stdenvNoCC.mkDerivation (
    finalAttrs: {
      name = "chrz";
      version = "0.1.0";
      src = lib.cleanSource ./.;
      nativeBuildInputs = [
        zig_hook
        makeWrapper
      ];

      deps = callPackage ./build.zig.zon.nix {name = "${finalAttrs.name}-${finalAttrs.version}";};

      zigBuildFlags = [
        "--system"
        "${finalAttrs.deps}"
      ];
      meta = {
        mainProgram = "chrz";
        license = lib.licenses.mit;
      };
    }
  )
