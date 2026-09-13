# Overlay for NixOS users who want to replace nixpkgs cosmic-comp (and
# cosmic-greeter) with this project's Vulkan-renderer bring-up branches:
# smithay (renderer support) + cosmic-comp (KmsApi runtime GLES/Vulkan
# selection) + cosmic-greeter (shares cosmic-comp's outputs.ron and needed the
# same EDID-serial output-identity fix). Tracking all three here, not just
# cosmic-comp/smithay, because the greeter reads cosmic-comp-config directly
# and inherits any fix or regression made there.
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
# hybrid-export smithay patches. Each cargoHash changes whenever its
# corresponding source tree changes; override the relevant one if
# fetchCargoVendor fails:
#
#   nixpkgs.overlays = [
#     (inputs.cosmic-vulkan.overlays.cosmic-vulkan {
#       cargoHash = "sha256-...";         # cosmic-comp
#       greeterCargoHash = "sha256-...";  # cosmic-greeter
#     })
#   ];
#
{
  cosmic-comp,
  smithay,
  cosmic-greeter,
}:
{
  # Computed 2026-09-13 against the pinned inputs in flake.lock at that time
  # (cosmic-comp dacfec6, cosmic-greeter 7e76893) - re-derive via the
  # documented hash-mismatch trick (build .cargoDeps with a placeholder hash
  # and read the "got:" value) whenever either input's Cargo.lock changes.
  cargoHash ? "sha256-SrcH1IRNvXBdMkddlds8IVlaSgvdn9jGv1XaEHzUtLE=",
  greeterCargoHash ? "sha256-N6fsXQb5nSsujWH0dTLvXs358bUe5vJFzZQJu0zuxSg=",
}:
final: prev:
let
  # Bump the whole COSMIC desktop to epoch-1.7.0 first (see
  # cosmic-epoch-1_7_0.nix for why), then layer the Vulkan-specific
  # cosmic-comp/cosmic-greeter overrides on top of *that* base rather than
  # on top of whatever version nixpkgs ships by default - so `old.pname`/
  # `old.buildInputs`/etc reflect the correct epoch-1.7.0 package shape, and
  # the resulting `-vulkan` version string chains from "1.7.0", not
  # whatever older version nixpkgs happens to have. `base` is everything
  # this overlay returns except the two packages Vulkan overrides again
  # below.
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
  libdisplayInfo = prev.libdisplay-info_0_3 or prev.libdisplay-info;

  # cosmic-greeter's own Cargo.toml already patches cosmic-comp-config to a
  # specific pinned rev on Pheoxy/cosmic-comp (not upstream pop-os/cosmic-comp,
  # which lacks the EDID-serial output-identity fix) - see cosmic-greeter's
  # `[patch."https://github.com/pop-os/cosmic-comp"]`. Cargo's own git
  # vendoring (via fetchCargoVendor below) resolves that during the build the
  # same way it already resolves every other git dependency, so - unlike
  # cosmic-comp's smithay path dependency above - no source bundling or
  # substitution is needed here; `cosmic-greeter` (the flake input) is used
  # directly as `src`. This does mean cosmic-greeter's pinned rev tracks
  # `cosmic-comp` independently and needs a manual bump (in cosmic-greeter's
  # own Cargo.toml) if `cosmic-comp`'s branch moves - the same maintenance a
  # non-Nix Cargo consumer of a git-patched dependency would have anyway.
  greeterOldVersion = base.cosmic-greeter.version or "1.7.0";
  greeterVersion = "${greeterOldVersion}-vulkan";
in
epoch170
// {
  cosmic-comp = base.cosmic-comp.overrideAttrs (old: {
    src = compSrc;
    version = compVersion;
    cargoHash = cargoHash;
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      src = compSrc;
      version = compVersion;
      inherit (old) pname;
      hash = cargoHash;
    };
    # `checkFeatures`/`cargoCheckFeatures` are NOT re-derived from
    # `buildFeatures`/`cargoBuildFeatures` on override: nixpkgs' rust generic
    # builder computes `cargoCheckFeatures = checkFeatures ? buildFeatures`
    # once, when `rustPlatform.buildRustPackage {...}` is originally
    # evaluated inside package.nix - before this overlay's `overrideAttrs`
    # ever runs. Since stock cosmic-comp never sets `buildFeatures`, that
    # already-baked `cargoCheckFeatures` stays `[]` even after this override
    # adds `renderer_vulkan` to `buildFeatures`/`cargoBuildFeatures` below -
    # without setting these too, `cargoCheckHook` (cosmic-comp's `cargo
    # test`/check phase, separate from the actual `cargoBuildHook` compile)
    # silently runs with no `renderer_vulkan`, hits the pre-existing
    # zoom-postprocessing bit-rot that's cfg'd out under that feature), and fails the whole build even though
    # the real compiled binary (from cargoBuildHook, which *does* get the
    # right features) is fine.
    buildFeatures = (old.buildFeatures or [ ]) ++ [ "renderer_vulkan" ];
    cargoBuildFeatures = (old.cargoBuildFeatures or [ ]) ++ [ "renderer_vulkan" ];
    checkFeatures = (old.checkFeatures or [ ]) ++ [ "renderer_vulkan" ];
    cargoCheckFeatures = (old.cargoCheckFeatures or [ ]) ++ [ "renderer_vulkan" ];
    buildInputs =
      (builtins.filter (p: (p.pname or "") != "libdisplay-info") (old.buildInputs or [ ]))
      ++ [
        prev.vulkan-loader
        libdisplayInfo
      ];
  });

  cosmic-greeter = base.cosmic-greeter.overrideAttrs (old: {
    src = cosmic-greeter;
    version = greeterVersion;
    cargoHash = greeterCargoHash;
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      src = cosmic-greeter;
      version = greeterVersion;
      inherit (old) pname;
      hash = greeterCargoHash;
    };
    env = (old.env or { }) // {
      VERGEN_GIT_SHA = greeterVersion;
    };
  });
}
