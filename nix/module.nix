# NixOS module: apply the Vulkan cosmic-comp/cosmic-greeter overlay and mark
# the session. Importing this replaces both GLES cosmic-comp and cosmic-greeter
# with this project's patched builds (the greeter needed the same
# output-identity fix cosmic-comp did, since it reads cosmic-comp's
# outputs.ron directly). Keep it off the default generation
# if you still want epoch COSMIC; use a specialisation or an opt-in host.
{ overlay }:
{ lib, ... }:
{
  nixpkgs.overlays = [ overlay ];
  environment.sessionVariables.COSMIC_RENDERER = "vulkan";
}
