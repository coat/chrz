{
  callPackage,
  elfkickers,
  lib,
  stdenvNoCC,
  zig,
}: let
  zig_hook = zig.hook.overrideAttrs {
    zig_default_flags = "-Dcpu=baseline -Doptimize=ReleaseSmall --color off";
  };
in
  stdenvNoCC.mkDerivation (
    finalAttrs: {
      name = "chrz";
      version = "0.5.0";
      src = lib.cleanSource ./.;

      nativeBuildInputs = [
        zig_hook
      ] ++ lib.optionals stdenvNoCC.isLinux [elfkickers];

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
