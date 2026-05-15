{
  inputs = { utils.url = "github:numtide/flake-utils"; };
  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            expect
            gitleaks
            mkcert
            nssTools
            openssl
            prek
            yamlfix
            zensical
          ];

          shellHook = ''
            export HOMELAB_MKCERT_ROOT="$(${pkgs.mkcert}/bin/mkcert -CAROOT)"

            if [ ! -f "$HOMELAB_MKCERT_ROOT/rootCA.pem" ]; then
              echo "mkcert CA is not installed yet. Run: mkcert -install"
            fi
          '';
        };

        devShell = self.devShells.${system}.default;
      });
}
