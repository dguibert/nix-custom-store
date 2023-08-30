{
  description = "a Nix overlays to install in a custon /nix/store";

  inputs.nix.url = "github:NixOS/nix";
  inputs.nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";

  outputs = { self, nix, nixpkgs }: {
    packages.x86_64-linux.nix = (nixpkgs.legacyPackages.x86_64-linux.appendOverlays [self.overlays.default]).nix;

    overlays.default = final: prev: with prev; {
      nixStore = builtins.trace "nixStore=/nix" "/nix";

      nix = prev.nix.overrideAttrs (o: {
        configureFlags = o.configureFlags
        ++ (lib.optionals (final.nixStore == "/nix") [ "--sysconfdir=/etc" ])
        ++ (lib.optionals (final.nixStore != "/nix") [
          "--with-store-dir=${final.nixStore}/store"
          "--localstatedir=${final.nixStore}/var"
          "--sysconfdir=${final.nixStore}/etc" ]);
      });
    };

  };
}
