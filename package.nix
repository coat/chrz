{
  callPackage,
  elfkickers,
  lib,
  stdenvNoCC,
  makeWrapper,
  zig,
}: let
  zig_hook = zig.hook.overrideAttrs {
    zig_default_flags = "-Dcpu=baseline -Doptimize=ReleaseSmall --color off";
  };
in
  stdenvNoCC.mkDerivation (
    finalAttrs: {
      name = "chrz";
      version = "0.4.0";
      src = lib.cleanSource ./.;
      nativeBuildInputs = [
        zig_hook
        makeWrapper
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
