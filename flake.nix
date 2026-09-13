{
  description = "NixOS overlay: COSMIC compositor + greeter with VulkanRenderer smithay (e3d461a pin). Bring-up toggle, not default GLES. Tracks smithay, cosmic-comp, and cosmic-greeter as the three individual project checkouts this effort spans.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    smithay.url = "github:Pheoxy/smithay/add-vulkan-renderer-support-cosmic-e3d461a";
    smithay.flake = false;
    cosmic-comp.url = "github:Pheoxy/cosmic-comp/vulkan-renderer-e3d461a";
    cosmic-comp.flake = false;
    # TODO: no `Pheoxy/cosmic-greeter` fork exists yet (checked 2026-09-13:
    # https://api.github.com/repos/Pheoxy/cosmic-greeter -> 404). Until one is
    # created and this branch is pushed there, point at the local checkout so
    # the flake still evaluates and builds on this machine. Swap this for
    # `github:Pheoxy/cosmic-greeter/output-identity-edid-serial` (matching the
    # smithay/cosmic-comp pattern above) once that fork exists - `nix flake
    # lock` won't need anything else changed at that point.
    cosmic-greeter.url = "path:/home/dhancock/Projects/cosmic-greeter";
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
