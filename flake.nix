{
  description = "NixOS overlay: COSMIC compositor + greeter + settings with VulkanRenderer smithay (e3d461a pin). Bring-up toggle, not default GLES. Tracks smithay, cosmic-comp, cosmic-greeter, and cosmic-settings as the four individual project checkouts this effort spans.";

  # Public binary cache with the outputs this flake builds (the four fork
  # packages, release and debug). Optional: Nix asks before trusting it, and
  # everything still builds from source without it.
  nixConfig = {
    extra-substituters = [ "https://camelot-network.cachix.org" ];
    extra-trusted-public-keys = [
      "camelot-network.cachix.org-1:rUls6tVSl0YGNvT7NZ54R5Ix9RRdwfJSC1OY8DaxLZk="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    smithay.url = "github:Pheoxy/smithay/add-vulkan-renderer-support-epoch-1.8.0";
    smithay.flake = false;
    cosmic-comp.url = "github:Pheoxy/cosmic-comp/vulkan-renderer-epoch-1.8.0";
    cosmic-comp.flake = false;
    cosmic-greeter.url = "github:Pheoxy/cosmic-greeter/output-identity-epoch-1.8.0";
    cosmic-greeter.flake = false;
    cosmic-settings.url = "github:Pheoxy/cosmic-settings/night-light-epoch-1.8.0";
    cosmic-settings.flake = false;
    # Builds cosmic-comp/cosmic-greeter/cosmic-settings with dependency
    # compilation cached separately from each package's own source - see
    # nix/overlay.nix.
    crane.url = "github:ipetkov/crane";
  };

  outputs =
    {
      self,
      nixpkgs,
      smithay,
      cosmic-comp,
      cosmic-greeter,
      cosmic-settings,
      crane,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkOverlay = import ./nix/overlay.nix {
        inherit cosmic-comp smithay cosmic-greeter cosmic-settings crane;
      };
    in
    {
      overlays.cosmic-vulkan = mkOverlay;
      overlays.default = mkOverlay;
      # The COSMIC release-alignment layer on its own, independent of the Vulkan
      # renderer work - overlays.cosmic-vulkan/default already apply this as
      # a base layer, so use this directly only if you want the bump without
      # the Vulkan renderer.
      overlays.cosmic-epoch = import ./nix/cosmic-epoch.nix;

      nixosModules.cosmic-vulkan = import ./nix/module.nix {
        overlay = self.overlays.default;
      };
      nixosModules.default = self.nixosModules.cosmic-vulkan;

      devShells = forAllSystems (system: {
        profiling = import ./nix/profiling-shell.nix {
          pkgs = nixpkgs.legacyPackages.${system};
        };
        default = self.devShells.${system}.profiling;
      });
    };
}
