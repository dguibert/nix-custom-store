{
  description = "a Nix overlays to install in a custon /nix/store";

  inputs.nix.url = "github:NixOS/nix";
  inputs.nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";

  outputs = { self, nix, nixpkgs }: let
    packages = system: nixpkgs.legacyPackages.${system}.appendOverlays [self.overlays.default];
  in {
    packages.x86_64-linux.nix = (packages "x86_64-linux").nix;
    packages.x86_64-linux.nixBinaryTarball = (packages "x86_64-linux").nixBinaryTarball;
    packages.x86_64-linux.nixBinaryTarballCrossAarch64 = (packages "x86_64-linux").pkgsCross.aarch64-multiplatform.nixBinaryTarball;

    overlays.default = final: prev: with prev; let
      # copied from nix/flake.nix
      binaryTarball = nix: pkgs:
        let
          inherit (pkgs) buildPackages;
          inherit (pkgs) cacert nixStore;
          installerClosureInfo = buildPackages.closureInfo { rootPaths = [ nix cacert ]; };
        in

        buildPackages.runCommand "nix-binary-tarball-${nix.version}"
          { #nativeBuildInputs = lib.optional (system != "aarch64-linux") shellcheck;
            meta.description = "Distribution-independent Nix bootstrap binaries for ${pkgs.system}";
          }
          ''
            cp ${installerClosureInfo}/registration $TMPDIR/reginfo
            cp ${nix.src}/scripts/create-darwin-volume.sh $TMPDIR/create-darwin-volume.sh
            substitute ${nix.src}/scripts/install-nix-from-closure.sh $TMPDIR/install \
              --subst-var-by nix ${nix} \
              --subst-var-by cacert ${cacert}
              sed -i -e 's|^dest=".*|dest="${nixStore}"|' $TMPDIR/install

            substitute ${nix.src}/scripts/install-darwin-multi-user.sh $TMPDIR/install-darwin-multi-user.sh \
              --subst-var-by nix ${nix} \
              --subst-var-by cacert ${cacert}
            substitute ${nix.src}/scripts/install-systemd-multi-user.sh $TMPDIR/install-systemd-multi-user.sh \
              --subst-var-by nix ${nix} \
              --subst-var-by cacert ${cacert}
            substitute ${nix.src}/scripts/install-multi-user.sh $TMPDIR/install-multi-user \
              --subst-var-by nix ${nix} \
              --subst-var-by cacert ${cacert}

            if type -p shellcheck; then
              # SC1090: Don't worry about not being able to find
              #         $nix/etc/profile.d/nix.sh
              shellcheck --exclude SC1090 $TMPDIR/install
              shellcheck $TMPDIR/create-darwin-volume.sh
              shellcheck $TMPDIR/install-darwin-multi-user.sh
              shellcheck $TMPDIR/install-systemd-multi-user.sh

              # SC1091: Don't panic about not being able to source
              #         /etc/profile
              # SC2002: Ignore "useless cat" "error", when loading
              #         .reginfo, as the cat is a much cleaner
              #         implementation, even though it is "useless"
              # SC2116: Allow ROOT_HOME=$(echo ~root) for resolving
              #         root's home directory
              shellcheck --external-sources \
                --exclude SC1091,SC2002,SC2116 $TMPDIR/install-multi-user
            fi

            chmod +x $TMPDIR/install
            chmod +x $TMPDIR/create-darwin-volume.sh
            chmod +x $TMPDIR/install-darwin-multi-user.sh
            chmod +x $TMPDIR/install-systemd-multi-user.sh
            chmod +x $TMPDIR/install-multi-user
            dir=nix-${nix.version}-${pkgs.system}
            fn=$out/$dir.tar.xz
            mkdir -p $out/nix-support
            echo "file binary-dist $fn" >> $out/nix-support/hydra-build-products
            tar cvfJ $fn \
              --owner=0 --group=0 --mode=u+rw,uga+r \
              --mtime='1970-01-01' \
              --absolute-names \
              --hard-dereference \
              --transform "s,$TMPDIR/install,$dir/install," \
              --transform "s,$TMPDIR/create-darwin-volume.sh,$dir/create-darwin-volume.sh," \
              --transform "s,$TMPDIR/reginfo,$dir/.reginfo," \
              --transform "s,$NIX_STORE,$dir/store,S" \
              $TMPDIR/install \
              $TMPDIR/create-darwin-volume.sh \
              $TMPDIR/install-darwin-multi-user.sh \
              $TMPDIR/install-systemd-multi-user.sh \
              $TMPDIR/install-multi-user \
              $TMPDIR/reginfo \
              $(cat ${installerClosureInfo}/store-paths)
          '';

    in {
      nixStore = builtins.trace "nixStore=/nix" "/nix";

      nix = prev.nix.overrideAttrs (o: {
        configureFlags = o.configureFlags
        ++ (lib.optionals (final.nixStore == "/nix") [ "--sysconfdir=/etc" ])
        ++ (lib.optionals (final.nixStore != "/nix") [
          "--with-store-dir=${final.nixStore}/store"
          "--localstatedir=${final.nixStore}/var"
          "--sysconfdir=${final.nixStore}/etc" ]);
      });

      nixBinaryTarball = binaryTarball final.nix final.pkgs;
    };

  };
}
