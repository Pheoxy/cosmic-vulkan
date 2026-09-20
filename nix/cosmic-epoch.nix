# COSMIC release alignment layer: pin every COSMIC desktop package to the
# pop-os epoch release this project is currently developed against.
#
# This layer is a permanent part of the overlay, not a stop-gap. nixpkgs'
# own `cosmic-*` packages sometimes lag the pop-os epoch release by one or
# more versions, and sometimes run ahead of it. Either way our Vulkan-patched
# `cosmic-comp`/`cosmic-greeter`/`cosmic-settings` (built from branches based
# on a specific epoch tag) would otherwise sit next to a stack of *other*
# COSMIC packages (`cosmic-panel`, `cosmic-session`, `cosmic-settings-daemon`,
# `xdg-desktop-portal-cosmic`, ...) from a different release - a mismatched
# desktop that can hit protocol/feature skew between components that are all
# supposed to be the same release. So: `epoch` below is bumped together with
# the fork branches whenever this project moves to a new release, and this
# file is kept in sync with that release regardless of what nixpkgs ships.
# When nixpkgs happens to be on the same release it is a no-op (same tags,
# same hashes - the values below are taken straight from nixpkgs' package
# files when it is aligned, and derived by hand when it is not).
#
# Also exposed standalone (`overlays.cosmic-epoch`) for anyone who wants the
# release alignment on its own, independent of the Vulkan renderer work.
#
# vs pop-os/cosmic-epoch:
# - .desktop/.metainfo generation moved into each app's build.rs by 1.8.0
#   (`scripts/xdgen` no longer exists); nixpkgs' cargo build runs it.
# - pop-launcher is in the epoch set and the NixOS module, but nixpkgs tracks
#   its crate tag (1.2.7); pin it to the epoch tag here.
# - cosmic-osk is packaged in Pop!_OS but not tagged in epoch yet; ship it as a
#   package only (not wired into any desktop module by this file).
# Skip: cosmic-theme-editor (archived), simple-wrapper (not installed upstream).
#
# Hash bootstrap when nixpkgs is *not* aligned: `nix build` with a placeholder
# hash and read the "got:" value from the mismatch error.

final: prev:
let
  inherit (prev) lib rustPlatform;
  epoch = "1.8.0";

  xdgen =
    src: cargoHash:
    rustPlatform.buildRustPackage {
      pname = "xdgen-generate";
      version = "0.1.0";
      inherit src cargoHash;
      meta.mainProgram = "xdgen-generate";
    };

  bump =
    name: spec:
    prev.${name}.overrideAttrs (
      old:
      let
        version = spec.version or epoch;
        src = old.src.override (
          lib.optionalAttrs (!(spec ? rev)) { tag = "epoch-${version}"; }
          // lib.optionalAttrs (spec ? rev) { inherit (spec) rev; }
          // lib.optionalAttrs (spec ? src) { hash = spec.src; }
          // lib.optionalAttrs (spec ? sha256) { sha256 = spec.sha256; }
        );
      in
      {
        inherit version src;
        doCheck = false;
      }
      // lib.optionalAttrs (spec ? cargoHash) {
        cargoHash = spec.cargoHash;
        cargoDeps = rustPlatform.fetchCargoVendor {
          inherit src version;
          inherit (old) pname;
          hash = spec.cargoHash;
        };
      }
      // lib.optionalAttrs ((old.env or { }) ? VERGEN_GIT_SHA) {
        env = old.env // {
          VERGEN_GIT_SHA = if spec ? rev then spec.rev else "epoch-${version}";
        };
      }
      // lib.optionalAttrs (spec ? xdgenCargoHash) {
        preInstall = ''
          env \
            APP_ID=${spec.xdgenAppId} \
            APP_NAME=${spec.xdgenAppName} \
            ${lib.getExe (xdgen "${src}/scripts/xdgen" spec.xdgenCargoHash)}
        '';
      }
    );

  specs = {
    cosmic-app-library = {
      src = "sha256-oAGo8ByFHiSR9J57Ytn9kjMRwu103Retr9VcZjjaTtY=";
      cargoHash = "sha256-UNSoRkHFQ1VpIeF/xMyONpwZ8hG5yUkTWqq/9LQ1wqs=";
    };
    cosmic-applets = {
      src = "sha256-OMz/lh5bJ7YjS6GLP+yQsJ9HvYNDedj2MMMA5pgwPEE=";
      cargoHash = "sha256-iGnqu6Di2kxEAujzJ+Yy+A4cUZrdDjQ7aF3yrVz+QYU=";
    };
    cosmic-bg = {
      src = "sha256-tvYVe3H99oB6NYzLjwzX+ccSFh54LAfvuLmFoCIaJp4=";
      cargoHash = "sha256-j07BZ9JsY6UG9eXVxdn0CTWU8j/cGNA9lXrDsdF40lM=";
    };
    cosmic-comp = {
      src = "sha256-axWy7F05WOt03WX4nYdObclFf3E12C4zxQ2eNLOjPp0=";
      cargoHash = "sha256-J9/7DVMyx4SV/BKhg4l9B4haRdGfspmoZjr8LPTzmgo=";
    };
    cosmic-edit = {
      src = "sha256-mZnL9W67hnHVS4wJBAprdPzU8VEq6mguzuhXjtPPIhc=";
      cargoHash = "sha256-NERnN9TqqpzI9kD2ujfs11W0RnVxU+Ra6GjGk3FGO3A=";
    };
    cosmic-files = {
      src = "sha256-AHb+DIoQ4LKE//QSFKxTbmmse1D9C6VYQ0vhiqnbFaY=";
      cargoHash = "sha256-wO4tci+Ocd9sIwp2lQN7RNKc+XeqvlSJGdViQ+lVt4Q=";
    };
    cosmic-greeter = {
      src = "sha256-mC8m6hbQ6VgJoFl7VFRkbKl4zev8pffKHRtzvXtwoRo=";
      cargoHash = "sha256-vHR9go8/iVUT7oBV8h+mmBvhi2oSKNBKtV0uoDOr6go=";
    };
    cosmic-icons = {
      src = "sha256-IlWVDJZBDn0RZaWpMx+mVJrcn5eqz2i6qDIjvQjkTZ4=";
    };
    cosmic-idle = {
      src = "sha256-0tcrOfVT5b57ev3b5F2U78F2QPGFwp94bqFVNyKH0Yk=";
      cargoHash = "sha256-wAjFC6qAC3nllbnZf0KVaZTEztNYo6GTvwcp5FYmXLw=";
    };
    cosmic-initial-setup = {
      src = "sha256-Qv95Q528TN/UafVS3C6yZqvbu/EDT+/Gj0Od50ZvIVs=";
      cargoHash = "sha256-pQmWdt53G/JJN37jTkGBYb1lfOT6aiwwNXKZGA9Es7w=";
    };
    cosmic-launcher = {
      src = "sha256-qfBP5EzI7+oVYt5MdY+WypG5SvsFvk46F78q/cwIpWo=";
      cargoHash = "sha256-NwIcWFnN6ulNq0RVMYLlYfHGbMTgd71mbqzAAP5ZCKc=";
    };
    cosmic-monitor = {
      src = "sha256-nItwje+QZkR0L+wOsmOVPJwo4THwiRLLvIFvH6XP31o=";
      cargoHash = "sha256-HHKIXKyS1zDkNGbsEWiKghPqIsPKRUJtjxKuNfI6mak=";
    };
    cosmic-notifications = {
      src = "sha256-HhhmsAngWseqXOPy5ra2BIakiBD9YskE2IsjqXaMVGs=";
      cargoHash = "sha256-32AoA17CO4noUzKhx+KDBpy5fWG4lvSBMK5aVJW8K9o=";
    };
    cosmic-osd = {
      src = "sha256-bb1NKMRl8gyQ8PRniS4eIrmjkZ2ayyMi2AkzejXV+3Y=";
      cargoHash = "sha256-C0GR/VWWu2zOAvAokQnM+g+OJqQM2s2WUf2ffwfZieI=";
    };
    cosmic-panel = {
      src = "sha256-Cl4F9vf39qLT/ZVCP9dUJ6YTQq47Wl8tbjbu1b+6tgY=";
      cargoHash = "sha256-XIthlStPM97vjhJTdofUOkOudH1id6W2U4YdOxEh/eo=";
    };
    pop-launcher = {
      # epoch-1.8.0 and epoch-1.7.0 tag the same tree (identical source hash).
      src = "sha256-OfUpbpAhUGUFunucRgbD+UXF40sl6PgpmJzUjbfn1Z8=";
      cargoHash = "sha256-k57ondlF1xu5/GU9QzKkT5F2caFNNPC6/Bj2HWwzzGI=";
    };
    cosmic-player = {
      src = "sha256-6AbCB1d4g9iy77HRXxEs0KT/7Ry6/quJs3Qumw5jTKI=";
      cargoHash = "sha256-9ReitIbvr6D+BGLa1xumi67DPG3YlgdA4pZ/rfvn4Cc=";
    };
    cosmic-randr = {
      src = "sha256-Jimw6YCRouG9FDlLBp15OOCRlywBIaP/K/bXLR7trQM=";
      cargoHash = "sha256-QWSPj7bxxWh5/KeNEtUsfDKg+JMONLjomrMcn57j6fw=";
    };
    cosmic-reader = {
      version = "0-unstable-2026-08-24";
      rev = "42ea9431705e665b9daf7681ded5f726e1b0389e";
      src = "sha256-Lu0kiEP7JOa9SLkg/VcYDAgmgURyzQ8HnOuxPWaI1nk=";
      cargoHash = "sha256-DPGpGWzAgdpHp3qzksLtLnfqk+DJsaukdT2ekFFiGaM=";
    };
    cosmic-screenshot = {
      src = "sha256-ww6QsrdDp19w3IDSWDm5mC9g6ze92ktPJ1Qyh5kUQS0=";
      cargoHash = "sha256-q0RJST1yeqPBjU5MseNZIrZw+brfDtQLKiw7wyViflE=";
    };
    cosmic-session = {
      src = "sha256-sYrWH8Ve/KBoSd7uoCbctdF33rRdrUnTT5MABXhZZEs=";
      cargoHash = "sha256-5dLG40X+yxJo566guyHqOCLNp+uNSE+HONS8GIDm58A=";
    };
    cosmic-settings = {
      src = "sha256-53DJw3oSVGsgpy/BNnxOT60J7kRB0kp18qrjP2IR4gI=";
      cargoHash = "sha256-NT4y838qjvdOuFLqAk6I2c5cHbmhMs3JrGoIIhw4+FE=";
    };
    cosmic-settings-daemon = {
      src = "sha256-D7f5IERgNP9JrmAIiHp6jlBZUOt+n8FpEiGx1jqqwgs=";
      cargoHash = "sha256-4rGgRc7EDdxGvFmAUY4kJ9aO/Pas9S2Q+b5ArZNydvs=";
    };
    cosmic-sound-theme = {
      sha256 = "sha256-hFWTn73SutdOZGbhkcsBR1TNabB+IOrxRndwXaikqN8=";
    };
    cosmic-store = {
      src = "sha256-z2w+FYNGsvRzCRp5EQ1QwrITHso2HhCAVz19M50Tk48=";
      cargoHash = "sha256-MxLb1ur7IwVAfAxViXXaFoVN35vhuIF1S1HRvg3wPo4=";
    };
    cosmic-term = {
      src = "sha256-eXy7gSjcBu3kALJEbHp7BgKg9H7FIgrKfGWgiad7Z1M=";
      cargoHash = "sha256-NN3kX0/ea7Q+QcWO8eAchsSaIVuudbf5dbCRiRZdnBg=";
    };
    cosmic-wallpapers = {
      src = "sha256-lCgWRtvaso9jKo7A4VepDFK/zc8pQpR1up8yoWS/qfc=";
    };
    cosmic-workspaces-epoch = {
      src = "sha256-ntn1mW6YKpSXNZQbkZRFhUHbZur3JtJD9A/MzI+AUMQ=";
      cargoHash = "sha256-0ZvnMT7wkMyZ9zHOBGZNh+DmLaoATHvpSplSnVgC/j4=";
    };
    xdg-desktop-portal-cosmic = {
      src = "sha256-UbWQSdC1GhizgFn9KMxJDT8rV8IaZ4hwDA0hQ14qc7o=";
      cargoHash = "sha256-cENH+9M4irNfsSioeP3yX38Ux1ESO0KXtaiiK3XuEtA=";
    };
  };
in
(lib.mapAttrs bump specs)
// {
  # Pop!_OS ships this; not in cosmic-epoch tags or the NixOS module yet.
  cosmic-osk = rustPlatform.buildRustPackage {
    pname = "cosmic-osk";
    version = "0-unstable-2026-09-05";

    src = prev.fetchFromGitHub {
      owner = "pop-os";
      repo = "cosmic-osk";
      rev = "0a859e3ec70d1029584d48983419c7b7bc7b8748";
      hash = "sha256-jNH5l3/PQsCGbOCTjghhWfTV3rc5580aKWfSTu9Pdzo=";
    };

    cargoHash = "sha256-QsyCfT7wmBxbR614Aic/tAI1FHtmIW5M9hDXABHuS0o=";

    separateDebugInfo = true;
    __structuredAttrs = true;
    doCheck = false;

    nativeBuildInputs = [
      prev.just
      prev.pkg-config
      prev.libcosmicAppHook
    ];

    buildInputs = [
      prev.libxkbcommon
      prev.udev
    ];

    dontUseJustBuild = true;
    dontUseJustCheck = true;

    justFlags = [
      "--set"
      "prefix"
      (placeholder "out")
      "--set"
      "cargo-target-dir"
      "target/${prev.stdenv.hostPlatform.rust.cargoShortTarget}"
    ];

    meta = {
      homepage = "https://github.com/pop-os/cosmic-osk";
      description = "On-screen keyboard for the COSMIC Desktop Environment";
      license = lib.licenses.gpl3Only;
      mainProgram = "cosmic-osk";
      platforms = lib.platforms.linux;
    };
  };
}
