# Overlay for NixOS users who want to replace nixpkgs cosmic-comp (and
# cosmic-greeter, cosmic-settings) with this project's Vulkan-renderer
# bring-up branches: smithay (renderer support) + cosmic-comp (KmsApi runtime
# GLES/Vulkan selection, plus the hardware CTM/GAMMA_LUT color pipeline) +
# cosmic-greeter (shares cosmic-comp's outputs.ron and needed the same
# EDID-serial output-identity fix) + cosmic-settings (the night-light toggle
# UI, a wlr-gamma-control-unstable-v1 client of cosmic-comp's new protocol
# support). Tracking all four here, not just cosmic-comp/smithay, because
# each of the others depends on or drives something cosmic-comp changed.
#
# Also applies cosmic-epoch-1_7_0.nix as a base layer before the Vulkan
# overrides, so the rest of the COSMIC desktop (cosmic-panel, cosmic-session,
# xdg-desktop-portal-cosmic, ...) is on the same epoch-1.7.0 release these
# branches were developed against, instead of leaving them on whatever older
# version nixpkgs ships by default - a mismatched desktop is a real way for
# this to "not work as well" for anyone who applies only this overlay. Use
# `overlays.cosmic-epoch-1_7_0` directly instead if you want that bump without
# the Vulkan renderer.
#
# Exclusive KMS Vulkan, not default COSMIC GLES. Do not mix with GLES
# hybrid-export smithay patches.
#
# All three forked packages are built via crane (see cosmic-comp-crane.nix,
# cosmic-greeter-crane.nix, cosmic-settings-crane.nix), not
# `rustPlatform.buildRustPackage` - dependency compilation is cached
# separately from each package's own source, so tracking a new commit on any
# of the four branches this overlay pulls in only recompiles what actually
# changed instead of the whole dependency tree every time. This also means
# there's no `cargoHash`/`greeterCargoHash`/`settingsCargoHash` to maintain
# any more - crane vendors straight from each package's own Cargo.lock, with
# no separate fixed-output-derivation hash to re-derive by hand whenever a
# Cargo.lock changes (the old failure mode this overlay used to need the
# hash-mismatch trick to recover from). Usage is now just:
#
#   nixpkgs.overlays = [ inputs.cosmic-vulkan.overlays.cosmic-vulkan ];
#
{
  cosmic-comp,
  smithay,
  cosmic-greeter,
  cosmic-settings,
  crane,
}:
final: prev:
let
  # Bump the whole COSMIC desktop to epoch-1.7.0 first (see
  # cosmic-epoch-1_7_0.nix for why), then layer the Vulkan-specific
  # cosmic-comp/cosmic-greeter overrides on top of *that* base rather than
  # on top of whatever version nixpkgs ships by default - so the resulting
  # `-vulkan` version string chains from "1.7.0", not whatever older version
  # nixpkgs happens to have. `base` is everything this overlay returns
  # except the three packages Vulkan overrides again below.
  epoch170 = import ./cosmic-epoch-1_7_0.nix final prev;
  base = prev // epoch170;

  compSrc = prev.runCommand "cosmic-comp-vulkan-src" { } ''
    cp -a ${cosmic-comp}/. "$out"
    chmod -R u+w "$out"
    rm -rf "$out/smithay" "$out/target" "$out/result"
    cp -a ${smithay} "$out/smithay"
    chmod -R u+w "$out/smithay"
    rm -rf "$out/smithay/target" "$out/smithay/result" "$out/smithay/.git"
    substituteInPlace "$out/Cargo.toml" \
      --replace-fail 'smithay = { path = "../smithay" }' \
                     'smithay = { path = "./smithay" }'
  '';
  compOldVersion = base.cosmic-comp.version or "1.7.0";
  compVersion = "${compOldVersion}-vulkan";

  # cosmic-greeter's own Cargo.toml already patches cosmic-comp-config to a
  # specific pinned rev on Pheoxy/cosmic-comp (not upstream pop-os/cosmic-comp,
  # which lacks the EDID-serial output-identity fix) - see cosmic-greeter's
  # `[patch."https://github.com/pop-os/cosmic-comp"]`. Cargo's own git
  # vendoring resolves that during the build the same way it resolves every
  # other git dependency, so - unlike cosmic-comp's smithay path dependency
  # above - no source bundling or substitution is needed here;
  # `cosmic-greeter` (the flake input) is used directly as `src`. This does
  # mean cosmic-greeter's pinned rev tracks `cosmic-comp` independently and
  # needs a manual bump (in cosmic-greeter's own Cargo.toml) if `cosmic-comp`'s
  # branch moves - the same maintenance a non-Nix Cargo consumer of a
  # git-patched dependency would have anyway.
  greeterOldVersion = base.cosmic-greeter.version or "1.7.0";
  greeterVersion = "${greeterOldVersion}-vulkan";

  # cosmic-settings needed no changes to how it's fetched/patched - unlike cosmic-comp, it has
  # no local path dependency to bundle; unlike cosmic-greeter, it has no git-patched dependency
  # on this project's other forks at all. It's just the "wayland" Cargo feature (off by default
  # in upstream nixpkgs' build) that needs enabling so the new night-light code (a
  # wlr-gamma-control-unstable-v1 client) is actually compiled in.
  settingsOldVersion = base.cosmic-settings.version or "1.7.0";
  settingsVersion = "${settingsOldVersion}-vulkan";
in
epoch170
// {
  cosmic-comp = import ./cosmic-comp-crane.nix {
    pkgs = prev;
    inherit crane;
    src = compSrc;
    version = compVersion;
  };

  cosmic-greeter = import ./cosmic-greeter-crane.nix {
    pkgs = prev;
    inherit crane;
    src = cosmic-greeter;
    version = greeterVersion;
  };

  cosmic-settings = import ./cosmic-settings-crane.nix {
    pkgs = prev;
    inherit crane;
    src = cosmic-settings;
    version = settingsVersion;
  };
}
