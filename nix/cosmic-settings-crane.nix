# Builds cosmic-settings via crane instead of `rustPlatform.buildRustPackage` +
# `overrideAttrs` - see cosmic-comp-crane.nix for the general rationale.
{
  pkgs,
  crane,
  src,
  version,
}:
let
  craneLib = crane.mkLib pkgs;

  # Matches nixpkgs' own package.nix: a libcosmicAppHook variant that skips
  # bundling cosmic-settings' own default-schema/icon resources into every
  # OTHER libcosmicApp-wrapped package's XDG_DATA_DIRS (only cosmic-settings
  # itself needs them, wired up explicitly below).
  libcosmicAppHook' = (pkgs.libcosmicAppHook.__spliced.buildHost or pkgs.libcosmicAppHook).override {
    includeSettings = false;
  };

  commonArgs = {
    inherit src version;
    pname = "cosmic-settings";
    strictDeps = true;

    nativeBuildInputs = [
      pkgs.cmake
      pkgs.just
      libcosmicAppHook'
      pkgs.pkg-config
      pkgs.rustPlatform.bindgenHook
    ];
    buildInputs = [
      pkgs.expat
      pkgs.fontconfig
      pkgs.freetype
      pkgs.libinput
      pkgs.pipewire
      pkgs.pulseaudio
      pkgs.udev
      pkgs.dav1d
    ];

    # `wayland` gates cosmic_randr's live connection code and the night-light
    # wlr-gamma-control-unstable-v1 client - off by default upstream.
    cargoExtraArgs = "--features wayland";
    # Read directly by cargo.just's own `cargo-target-dir := env('CARGO_TARGET_DIR', 'target')`
    # (imported by the main justfile) - keeps crane's build and `just install`
    # looking in the same place.
    CARGO_TARGET_DIR = "target";
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (
  commonArgs
  // {
    inherit cargoArtifacts;

    installPhaseCommand = ''
      just --set prefix "$out" install
    '';

    preFixup = ''
      libcosmicAppWrapperArgs+=(
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.cosmic-randr ]}
        --prefix XDG_DATA_DIRS : ${pkgs.lib.makeSearchPathOutput "bin" "share" [ pkgs.isocodes ]}
        --set-default X11_BASE_RULES_XML ${pkgs.xkeyboard_config}/share/X11/xkb/rules/base.xml
        --set-default X11_BASE_EXTRA_RULES_XML ${pkgs.xkeyboard_config}/share/X11/xkb/rules/extra.xml
      )
    '';

    meta = {
      mainProgram = "cosmic-settings";
      license = pkgs.lib.licenses.gpl3Only;
      platforms = pkgs.lib.platforms.linux;
    };
  }
)
