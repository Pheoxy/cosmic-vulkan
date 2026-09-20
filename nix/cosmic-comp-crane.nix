# Builds cosmic-comp via crane instead of `rustPlatform.buildRustPackage` +
# `overrideAttrs`, splitting the build into a deps-only derivation (cached
# across edits to cosmic-comp's own source, as long as Cargo.lock doesn't
# change) and the real crate build - so tracking a new commit on
# `vulkan-renderer-e3d461a` doesn't force a full recompile of every
# dependency each time, only ones Cargo.lock itself changed.
#
# See also cosmic-greeter-crane.nix and cosmic-settings-crane.nix (same
# rationale, their own justfile-driven install instead of this Makefile one).
#
# Replicates nixpkgs' own cosmic-comp package.nix (buildInputs,
# nativeBuildInputs, the Makefile-driven install, libcosmicAppHook wrapping)
# as closely as possible so the packaging behavior matches the
# `overrideAttrs`-based version this replaces - just with crane doing the
# actual compile instead of buildRustPackage. Unlike buildRustPackage's
# `cargoHash`/`fetchCargoVendor`, crane vendors dependencies straight from
# `Cargo.lock` with no separate hash to maintain - this project's overlay no
# longer needs `cargoHash`/`greeterCargoHash`/`settingsCargoHash` arguments
# at all as of this port; see the README for the updated usage.
{
  pkgs,
  crane,
  src,
  version,
}:
let
  craneLib = crane.mkLib pkgs;
  libdisplayInfo = pkgs.libdisplay-info_0_3 or pkgs.libdisplay-info;

  commonArgs = {
    inherit src version;
    pname = "cosmic-comp";
    strictDeps = true;

    nativeBuildInputs = [
      pkgs.libcosmicAppHook
      pkgs.pkg-config
    ];
    # Filters out whatever libdisplay-info version cosmic-comp's own
    # buildInputs would otherwise pull in, in favor of the pinned 0.3 line
    # cosmic-comp's Cargo.lock expects - matters on nixpkgs revisions where
    # the top-level `libdisplay-info` attribute has moved past 0.3.
    buildInputs = (
      builtins.filter (p: (p.pname or "") != "libdisplay-info") [
        pkgs.libgbm
        pkgs.libinput
        pkgs.pixman
        pkgs.seatd
        pkgs.systemd
        pkgs.udev
      ]
    )
    ++ [
      pkgs.vulkan-loader
      libdisplayInfo
    ];

    cargoExtraArgs = "--features renderer_vulkan";
    # crane's own knob for cargo's `--profile`. This overlay always builds
    # release (matching nixpkgs' own cosmic-comp package.nix, which never
    # sets cargoBuildType either) - a debug/dev-tracing variant is specific
    # to this project's own local dev use, not something the published
    # overlay needs to offer.
    CARGO_PROFILE = "release";
    # A real environment variable (cargo itself reads this), not just a
    # `make`-flag string - cosmic-comp's Makefile `install` target expects
    # the binary at this exact path, so both the cargo build (here, applying
    # to buildDepsOnly's cache too, so its layout matches) and the later
    # `make install` (via makeFlags below) need to agree on it.
    CARGO_TARGET_DIR = "target/${pkgs.stdenv.hostPlatform.rust.cargoShortTarget}";
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (
  commonArgs
  // {
    inherit cargoArtifacts;

    # Same Makefile-driven install cosmic-comp's own package.nix uses
    # (`dontCargoInstall = true` there disables buildRustPackage's own
    # cargo-install step in favor of it) - crane has no equivalent
    # `dontCargoInstall`, so just replace its default
    # installFromCargoBuildLogHook-based install outright.
    makeFlags = [
      "prefix=${placeholder "out"}"
      "CARGO_TARGET_DIR=target/${pkgs.stdenv.hostPlatform.rust.cargoShortTarget}"
    ];
    installPhaseCommand = "make $makeFlags install";

    env.NIX_MAIN_PROGRAM = "cosmic-comp";

    meta = {
      mainProgram = "cosmic-comp";
      license = pkgs.lib.licenses.gpl3Only;
      platforms = pkgs.lib.platforms.linux;
    };
  }
)
