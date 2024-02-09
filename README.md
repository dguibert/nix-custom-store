# Nix with a custom store

[Nix](https://nixos/org/nix) is a package manager for Linux and other Unix systems that makes package management reliable and reproducible.

This repository provides an overlay to build Nix with a custom store if you want or don't have access to the default `/nix` directory.

# Usage in a flake

You use in in a flake as
````nix
{
    description = "custom nix";
    
    inputs.nix-custom-store.url = "github:dguibert/nix-custom-store";
    
    outputs = { self, nixpkgs, nix-custom-store, ...}@inputs: 
    let
    packages = system: nixpkgs.legacyPackages.${system}.appendOverlays [
      nix-custom-store.overlays.default
      self.overlays.default
    ];
    in {
        packages.x86_64-linux.nix = (packages "x86_64-linux").nix;
        overlays.default = final: prev: {
            nixStore = builtins.trace "nixStore=/custom-nix" "/custom-nix";
        };
    };
}
````
