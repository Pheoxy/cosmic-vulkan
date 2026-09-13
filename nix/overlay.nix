# Overlay for NixOS users who want to replace nixpkgs cosmic-comp (and
# cosmic-greeter) with this project's Vulkan-renderer bring-up branches:
# smithay (renderer support) + cosmic-comp (KmsApi runtime GLES/Vulkan
# selection) + cosmic-greeter (shares cosmic-comp's outputs.ron and needed the
# same EDID-serial output-identity fix). Tracking all three here, not just
# cosmic-comp/smithay, because the greeter reads cosmic-comp-config directly
# and inherits any fix or regression made there.
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
  cargoHash ? "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
  greeterCargoHash ? "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
}:
final: prev:
let
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
  compOldVersion = prev.cosmic-comp.version or "1.0.0";
  compVersion = "${compOldVersion}-vulkan";
  libdisplayInfo = prev.libdisplay-info_0_3 or prev.libdisplay-info;

  # cosmic-greeter's cosmic-comp-config comes from pop-os/cosmic-comp's
  # unpatched master by default (see cosmic-greeter's own Cargo.toml
  # `[patch."https://github.com/pop-os/cosmic-comp"]`, which points at a
  # local `../cosmic-comp/cosmic-comp-config` for dev builds outside Nix) -
  # bundle this branch's cosmic-comp-config into the sandbox and repoint the
  # patch at it, the same way compSrc bundles smithay into cosmic-comp above.
  greeterSrc = prev.runCommand "cosmic-greeter-vulkan-src" { } ''
    cp -a ${cosmic-greeter}/. "$out"
    chmod -R u+w "$out"
    rm -rf "$out/target" "$out/result"
    cp -a ${cosmic-comp}/cosmic-comp-config "$out/cosmic-comp-config"
    chmod -R u+w "$out/cosmic-comp-config"
    rm -rf "$out/cosmic-comp-config/target"
    substituteInPlace "$out/Cargo.toml" \
      --replace-fail 'cosmic-comp-config = { path = "../cosmic-comp/cosmic-comp-config" }' \
                     'cosmic-comp-config = { path = "./cosmic-comp-config" }'
  '';
  greeterOldVersion = prev.cosmic-greeter.version or "1.6.0";
  greeterVersion = "${greeterOldVersion}-vulkan";
in
{
  cosmic-comp = prev.cosmic-comp.overrideAttrs (old: {
    src = compSrc;
    version = compVersion;
    cargoHash = cargoHash;
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      src = compSrc;
      version = compVersion;
      inherit (old) pname;
      hash = cargoHash;
    };
    buildFeatures = (old.buildFeatures or [ ]) ++ [ "renderer_vulkan" ];
    cargoBuildFeatures = (old.cargoBuildFeatures or [ ]) ++ [ "renderer_vulkan" ];
    buildInputs =
      (builtins.filter (p: (p.pname or "") != "libdisplay-info") (old.buildInputs or [ ]))
      ++ [
        prev.vulkan-loader
        libdisplayInfo
      ];
  });

  cosmic-greeter = prev.cosmic-greeter.overrideAttrs (old: {
    src = greeterSrc;
    version = greeterVersion;
    cargoHash = greeterCargoHash;
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      src = greeterSrc;
      version = greeterVersion;
      inherit (old) pname;
      hash = greeterCargoHash;
    };
    env = (old.env or { }) // {
      VERGEN_GIT_SHA = greeterVersion;
    };
  });
}
