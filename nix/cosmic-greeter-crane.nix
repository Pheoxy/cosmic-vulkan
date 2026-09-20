# Builds cosmic-greeter via crane instead of `rustPlatform.buildRustPackage` +
# `overrideAttrs` - see cosmic-comp-crane.nix for the general rationale.
{
  pkgs,
  crane,
  src,
  version,
}:
let
  craneLib = crane.mkLib pkgs;

  commonArgs = {
    inherit src version;
    pname = "cosmic-greeter";
    strictDeps = true;

    nativeBuildInputs = [
      pkgs.rustPlatform.bindgenHook
      pkgs.cmake
      pkgs.just
      pkgs.libcosmicAppHook
    ];
    buildInputs = [
      pkgs.cosmic-randr
      pkgs.dav1d
      pkgs.libinput
      pkgs.linux-pam
      pkgs.udev
      pkgs.orca
    ];

    # Matches the justfile's own `build-release`/`build-debian` targets
    # building every workspace binary (cosmic-greeter + cosmic-greeter-daemon),
    # not just the main one.
    cargoExtraArgs = "--all";
    env.VERGEN_GIT_SHA = version;
    # Read directly by the justfile's own `cargo-target-dir := env('CARGO_TARGET_DIR', 'target')` -
    # keeps crane's build and `just install` looking in the same place.
    CARGO_TARGET_DIR = "target";
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (
  commonArgs
  // {
    inherit cargoArtifacts;

    # Only on the real build, not buildDepsOnly above - that one compiles
    # against a stub source tree derived from Cargo.toml/Cargo.lock alone,
    # where src/greeter.rs doesn't exist at all.
    postPatch = ''
      substituteInPlace src/greeter.rs --replace-fail '/usr/bin/env' '${pkgs.lib.getExe' pkgs.coreutils "env"}'
      substituteInPlace src/greeter.rs --replace-fail '/usr/bin/orca' '${pkgs.lib.getExe pkgs.orca}'
    '';

    installPhaseCommand = ''
      just --set prefix "$out" install
    '';

    preFixup = ''
      libcosmicAppWrapperArgs+=(
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.cosmic-randr ]}
        --set-default X11_BASE_RULES_XML ${pkgs.xkeyboard_config}/share/X11/xkb/rules/base.xml
        --set-default X11_BASE_EXTRA_RULES_XML ${pkgs.xkeyboard_config}/share/X11/xkb/rules/extra.xml
      )
    '';

    meta = {
      mainProgram = "cosmic-greeter";
      license = pkgs.lib.licenses.gpl3Only;
      platforms = pkgs.lib.platforms.linux;
    };
  }
)
