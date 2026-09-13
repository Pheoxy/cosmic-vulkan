{
  description = "NixOS overlay: COSMIC compositor + greeter with VulkanRenderer smithay (e3d461a pin). Bring-up toggle, not default GLES. Tracks smithay, cosmic-comp, and cosmic-greeter as the three individual project checkouts this effort spans.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    smithay.url = "github:Pheoxy/smithay/add-vulkan-renderer-support-cosmic-e3d461a";
    smithay.flake = false;
    cosmic-comp.url = "github:Pheoxy/cosmic-comp/vulkan-renderer-e3d461a";
    cosmic-comp.flake = false;
    cosmic-greeter.url = "github:Pheoxy/cosmic-greeter/output-identity-edid-serial";
    cosmic-greeter.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      smithay,
      cosmic-comp,
      cosmic-greeter,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkOverlay = import ./nix/overlay.nix {
        inherit cosmic-comp smithay cosmic-greeter;
      };
    in
    {
      overlays.cosmic-vulkan = mkOverlay;
      overlays.default = mkOverlay { };
      # The epoch-1.7.0 desktop bump on its own, independent of the Vulkan
      # renderer work - overlays.cosmic-vulkan/default already apply this as
      # a base layer, so use this directly only if you want the bump without
      # the Vulkan renderer.
      overlays.cosmic-epoch-1_7_0 = import ./nix/cosmic-epoch-1_7_0.nix;

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
