{
    description = "custom nix";

    inputs.nix-custom-store.url = "github:dguibert/nix-custom-store";

    outputs = { self, nixpkgs, nix-custom-store, ...}@inputs:
    let
    packages = system: nixpkgs.legacyPackages.${system}.appendOverlays [
      self.overlays.default
    ];
    in {
        packages.x86_64-linux.nix = (packages "x86_64-linux").nix;
        overlays.default = final: prev: {
            nixStore = builtins.trace "nixStore=/home_nfs_robin_ib/bguibertd/nix" "/home_nfs_robin_ib/bguibertd/nix";
        };
    };
}
