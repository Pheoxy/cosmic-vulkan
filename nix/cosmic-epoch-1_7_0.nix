# COSMIC 1.7.0: override official nixpkgs packages to pop-os epoch-1.7.0.
#
# Ported from a working host config (originally
# `~/Projects/nixos/overlays/cosmic-desktop.nix`) - nixpkgs' own `cosmic-*`
# packages generally lag the actual pop-os epoch release by one or more
# versions. Without this, `overlay.nix`'s Vulkan-patched `cosmic-comp`/
# `cosmic-greeter` end up sitting next to a stack of *other* COSMIC packages
# (`cosmic-panel`, `cosmic-session`, `cosmic-settings-daemon`,
# `xdg-desktop-portal-cosmic`, ...) that are one or more epochs behind - a
# mismatched desktop that can hit protocol/feature skew between components
# that are all supposed to be the same release. `overlay.nix` applies this
# overlay itself before layering its own `cosmic-comp`/`cosmic-greeter`
# overrides on top, so anyone using `overlays.cosmic-vulkan`/`overlays.default`
# gets a consistent 1.7.0-based desktop, not just a patched compositor alone.
#
# This file is also exposed standalone (`overlays.cosmic-epoch-1_7_0`) for
# anyone who wants the epoch-1.7.0 bump on its own, independent of the
# Vulkan renderer work - it is a complete, working overlay by itself.
#
# Drop this overlay once nixpkgs PR #556651 lands (and pop-launcher follows).
#
# vs pop-os/cosmic-epoch:
# - Most apps generate .desktop/.metainfo via xdgen in cargo build.rs; nixpkgs
#   cargo build already runs that. cosmic-app-library and cosmic-launcher at
#   1.7.0 still use scripts/xdgen (master has since moved those to build.rs).
# - pop-launcher is in the epoch set and the NixOS module, but nixpkgs is still
#   on crate tag 1.2.7; bump it to epoch-1.7.0 here (adds cosmic_toplevel, etc.).
# - cosmic-osk is packaged in Pop!_OS but not tagged in epoch yet; ship it as a
#   package only (not wired into any desktop module by this file).
# Skip: cosmic-theme-editor (archived), simple-wrapper (not installed upstream).
#
# cargoHash/src values below are pinned to specific epoch-1.7.0 source
# revisions; re-derive via the usual hash-mismatch bootstrap trick
# (`nix build` with a placeholder hash, read the "got:" value) if nixpkgs'
# own package definitions for any of these drift enough to change what gets
# vendored.

final: prev:
let
  inherit (prev) lib rustPlatform;
  epoch = "1.7.0";

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
      src = "sha256-g77/wMG0e8yMYLnwfOTupJlBOKKGYpsbRNxkjCsCfvY=";
      cargoHash = "sha256-pr90LG3H8hKD1dJAeO4vfLQLlihB7gjwvhlDNHdRTec=";
      xdgenCargoHash = "sha256-u3ia4MOL1cNj3K5ofJ5piwEDsDna2ImZh9uSVRPIQ/o=";
      xdgenAppId = "com.system76.CosmicAppLibrary";
      xdgenAppName = "cosmic-app-library";
    };
    cosmic-applets = {
      src = "sha256-DPqumlRrY666kR8/PewUKs4Bsb70H59vmFtnWX6Q95g=";
      cargoHash = "sha256-xgpsIynrVcN62IQ++ABZqqbP0ak86eQYTc1SCSxy2l4=";
    };
    cosmic-bg = {
      src = "sha256-tvYVe3H99oB6NYzLjwzX+ccSFh54LAfvuLmFoCIaJp4=";
      cargoHash = "sha256-j07BZ9JsY6UG9eXVxdn0CTWU8j/cGNA9lXrDsdF40lM=";
    };
    cosmic-comp = {
      src = "sha256-ZzEP2vErksBjohshiLpS3cMLsiwumIO8Ncg5UWt2nZ0=";
      cargoHash = "sha256-g5DCr8x8UQik8dSg+799lRDBeQQ47XvI7EbanR1de2k=";
    };
    cosmic-edit = {
      src = "sha256-gkU7oIWCOP7c/fIJPhLMyken0C5FqgGsayO4SOplMvI=";
      cargoHash = "sha256-qS5/jTh9tFprkBolXvjTuU6MOa0hxHiUTZ8JCeQli9g=";
    };
    cosmic-files = {
      src = "sha256-fuzsSlU1ZnneCXE6gx/0G4d6p4UEjorInTHg16QP0y0=";
      cargoHash = "sha256-QyRzX0aH6u6h0HM8kRrCY60btgSDGvQ8e7ZcENf+WFI=";
    };
    cosmic-greeter = {
      src = "sha256-Yi+MrPo8VMxghblAhIWbXli3wGtklzoyI8GbaaZO6Qo=";
      cargoHash = "sha256-vHR9go8/iVUT7oBV8h+mmBvhi2oSKNBKtV0uoDOr6go=";
    };
    cosmic-icons = {
      src = "sha256-QUTAYIQ6qAhjZK/9BZjJzTViECLUwO/MyaOqiRb1Ans=";
    };
    cosmic-idle = {
      src = "sha256-0tcrOfVT5b57ev3b5F2U78F2QPGFwp94bqFVNyKH0Yk=";
      cargoHash = "sha256-wAjFC6qAC3nllbnZf0KVaZTEztNYo6GTvwcp5FYmXLw=";
    };
    cosmic-initial-setup = {
      src = "sha256-P/F7hPKY9M3GoMmNi+lgmA5+lv5swcUA+B8FdyRSjPo=";
      cargoHash = "sha256-pQmWdt53G/JJN37jTkGBYb1lfOT6aiwwNXKZGA9Es7w=";
    };
    cosmic-launcher = {
      src = "sha256-zlqFX2DNQu5LqxbBcPK22H8N076k2JwmhNaVcnZbk1I=";
      cargoHash = "sha256-rD3zgkf13cc2YgDWcKxs3MDH4aORVz+dsxpm5tqrszU=";
      xdgenCargoHash = "sha256-Zf41g3ZpY0McDGhvmKReV77p4/laHUIBNievOMGbToE=";
      xdgenAppId = "com.system76.CosmicLauncher";
      xdgenAppName = "cosmic-launcher";
    };
    cosmic-monitor = {
      src = "sha256-axg/T3x2NMoGjVMrR381eoCNegUYr8vUpz0gIIYN7fY=";
      cargoHash = "sha256-4LYcW9wQXxrWlxc8VYeYTX29Rbu7pkXtb/BbsHludcQ=";
    };
    cosmic-notifications = {
      src = "sha256-HhhmsAngWseqXOPy5ra2BIakiBD9YskE2IsjqXaMVGs=";
      cargoHash = "sha256-32AoA17CO4noUzKhx+KDBpy5fWG4lvSBMK5aVJW8K9o=";
    };
    cosmic-osd = {
      src = "sha256-cVTR13WydvpPdtz+ewZ9nWjMfwHA/j3enm0L7r3+kog=";
      cargoHash = "sha256-5hput7WMstON8YG9GNNU61T+bQevGV72mAHYMtJJXng=";
    };
    cosmic-panel = {
      src = "sha256-dx+k+A5ZXo9MXuUxjdEd4xEqscuaNdVoojQzCWUNy/g=";
      cargoHash = "sha256-XIthlStPM97vjhJTdofUOkOudH1id6W2U4YdOxEh/eo=";
    };
    pop-launcher = {
      src = "sha256-OfUpbpAhUGUFunucRgbD+UXF40sl6PgpmJzUjbfn1Z8=";
      cargoHash = "sha256-k57ondlF1xu5/GU9QzKkT5F2caFNNPC6/Bj2HWwzzGI=";
    };
    cosmic-player = {
      src = "sha256-8XKgUpSrbzQS/E41aujxw2kz0reYQh+yeOP2k37ACA4=";
      cargoHash = "sha256-SVCwoQuIHHrd2FBoWJeXIhYev//bVcl9XtGm6QzOVK4=";
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
      src = "sha256-cxCLyLISM20UdxF0cdn7UAEa9uDihy71OS/357cbayI=";
      cargoHash = "sha256-2CKyNmtGUF0qzNjSR06lBqtC4DVtxZ5dAqLhEzjWCR4=";
    };
    cosmic-settings-daemon = {
      src = "sha256-bs5wP53jswti8l28fIJu5PG3mKuM1IJqeIef3LhMarA=";
      cargoHash = "sha256-4rGgRc7EDdxGvFmAUY4kJ9aO/Pas9S2Q+b5ArZNydvs=";
    };
    cosmic-sound-theme = {
      sha256 = "sha256-hFWTn73SutdOZGbhkcsBR1TNabB+IOrxRndwXaikqN8=";
    };
    cosmic-store = {
      src = "sha256-ME5Mgzpc3fCxI3UR6ifSsnjMvMD0C325v/MvNiYKjFw=";
      cargoHash = "sha256-g4MenwLRy7fd1puyUL3XeESpj4JvWObTsc9tFaWUXGQ=";
    };
    cosmic-term = {
      src = "sha256-IXtzZMzy5/wC/9k3dRuntF5YKNMaAVFRrDuG2qP3rpc=";
      cargoHash = "sha256-mXZuEHOh3YI5slbkY24FHwyIR2zGTYykeyDHBvc0IJs=";
    };
    cosmic-wallpapers = {
      src = "sha256-lCgWRtvaso9jKo7A4VepDFK/zc8pQpR1up8yoWS/qfc=";
    };
    cosmic-workspaces-epoch = {
      src = "sha256-yOGeAuJU8/9IljQPy3wEuzD/hFHwIn+Rm0OWDeTeOHE=";
      cargoHash = "sha256-0ZvnMT7wkMyZ9zHOBGZNh+DmLaoATHvpSplSnVgC/j4=";
    };
    xdg-desktop-portal-cosmic = {
      src = "sha256-2+ni2lWa2d/A5nN7iKNFwE3IQwO4hl9JX385rzXKrA4=";
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
