# cosmic-vulkan

A NixOS overlay/module that replaces the stock COSMIC compositor and greeter
with builds from an in-progress Vulkan renderer for `cosmic-comp`, on top of
a consistent COSMIC epoch-1.7.0 desktop. This is a bring-up/tracking project,
not an official COSMIC release - default COSMIC installs should keep using
GLES.

## What this tracks

Four individual project forks, each carrying the changes this effort needs:

| Package | Fork | Branch |
|---|---|---|
| [`smithay`](https://github.com/Pheoxy/smithay) | Vulkan renderer support for `cosmic-comp` | `add-vulkan-renderer-support-cosmic-e3d461a` |
| [`cosmic-comp`](https://github.com/Pheoxy/cosmic-comp) | Runtime GLES/Vulkan renderer selection (`KmsApi`, `COSMIC_RENDERER` env var), an EDID-serial-based output-identity fix, and a hardware `CTM`/`GAMMA_LUT` color pipeline (accessibility screen filter + a `wlr-gamma-control-unstable-v1` server for night light) | `vulkan-renderer-e3d461a` |
| [`cosmic-greeter`](https://github.com/Pheoxy/cosmic-greeter) | The same output-identity fix as `cosmic-comp` - the greeter reads `cosmic-comp`'s `outputs.ron` directly and shared the same connector-name-only matching bug | `output-identity-edid-serial` |
| [`cosmic-settings`](https://github.com/Pheoxy/cosmic-settings) | Re-enables the night-light toggle (dormant since 2024, kept ready for exactly this) as a client of `cosmic-comp`'s new gamma-control protocol support | `night-light-vulkan` |

`cosmic-comp`, `cosmic-greeter`, and `cosmic-settings` are Vulkan-patched by
this overlay. Everything else in the COSMIC desktop (`cosmic-panel`,
`cosmic-session`, `xdg-desktop-portal-cosmic`, ...) is left as whatever
epoch-1.7.0 build this overlay's `cosmic-epoch-1_7_0.nix` bump provides - see
below for why that matters.

Why `cosmic-greeter` is tracked here at all, not just `cosmic-comp`+`smithay`:
it shares the exact same output-identity bug as `cosmic-comp` (both read the
same `outputs.ron`), so a NixOS user applying only a Vulkan-patched
`cosmic-comp` without the matching `cosmic-greeter` fix would still hit the
bug at their login screen even though their session compositor is fixed.

## Usage

```nix
{
  inputs.cosmic-vulkan.url = "github:Pheoxy/cosmic-vulkan";

  # in your NixOS configuration:
  imports = [ inputs.cosmic-vulkan.nixosModules.default ];
  # or, if you want more control than the module gives you:
  nixpkgs.overlays = [ inputs.cosmic-vulkan.overlays.default ];
}
```

The module (`nixosModules.default`/`nixosModules.cosmic-vulkan`) applies the
overlay and sets `environment.sessionVariables.COSMIC_RENDERER = "vulkan"`
for you. Importing it replaces GLES `cosmic-comp`/`cosmic-greeter` for the
*entire* generation it's imported into - put it behind a
[specialisation](https://nixos.org/manual/nixos/stable/#sec-specialisation)
if you want to keep a normal GLES generation to boot back into, rather than
importing it directly into your main config:

```nix
specialisation.cosmic-vulkan.configuration = {
  imports = [ inputs.cosmic-vulkan.nixosModules.default ];
};
```

Pick the resulting boot entry to try the Vulkan renderer; reboot into the
untagged generation to go back to GLES.

### Overriding `cargoHash`

`overlays.cosmic-vulkan` (unlike `overlays.default`, which is this called
with no arguments) is a function that takes the cargo vendor hashes, in
case the tracked branches move and the hashes baked into `nix/overlay.nix`
go stale:

```nix
nixpkgs.overlays = [
  (inputs.cosmic-vulkan.overlays.cosmic-vulkan {
    cargoHash = "sha256-...";          # cosmic-comp
    greeterCargoHash = "sha256-...";   # cosmic-greeter
    settingsCargoHash = "sha256-...";  # cosmic-settings
  })
];
```

Get the real hash by building with a placeholder
(`sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=`) and reading the
"got:" value from the resulting hash-mismatch error - `nix build` will refuse
to build but tells you the real hash directly. No need to guess or run a
separate `nix-prefetch`-style tool.

### Epoch-1.7.0 without Vulkan

If you want the epoch-1.7.0 desktop bump on its own, without the Vulkan
renderer at all:

```nix
nixpkgs.overlays = [ inputs.cosmic-vulkan.overlays.cosmic-epoch-1_7_0 ];
```

This exists because nixpkgs' own `cosmic-*` packages generally lag the actual
pop-os epoch release by one or more versions - `overlays.cosmic-vulkan`/
`default` already apply this overlay as a base layer for you, so you don't
need to add both together.

## Development

```sh
nix develop           # or: nix develop .#profiling
```

Gives you `tracy`, `renderdoc`, `perf`/`hotspot`, `cargo-flamegraph`,
`vulkan-tools`, `vulkan-validation-layers`, and `drm_info` for
compositor-side profiling and debugging, with `LD_LIBRARY_PATH`/
`VK_DRIVER_FILES`/`VK_LAYER_PATH` set up for the host's Vulkan drivers and
validation layers.

## Status

Bring-up/tracking project, not a finished renderer. See
[`FEATURES.md`](FEATURES.md) for a feature-by-feature GLES vs. Vulkan
comparison and benchmark results, [`ISSUES.md`](ISSUES.md) for bugs found
during development tracked against their upstream status, and each fork's
own commit history for implementation detail.
