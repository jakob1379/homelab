{
  inputs = {
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils, git-hooks }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pre-commit-check = git-hooks.lib.${system}.run {
          src = ./.;
          package = pkgs.prek;

          hooks = {
            trim-trailing-whitespace.enable = true;
            end-of-file-fixer.enable = true;
            check-yaml = {
              enable = true;
              excludes = [ "^home-assistant/configuration\\.yaml$" ];
            };
            check-added-large-files.enable = true;
            check-case-conflicts.enable = true;
            check-executables-have-shebangs.enable = true;
            detect-private-keys.enable = true;
            check-merge-conflicts.enable = true;
            check-json = {
              enable = true;
              files = "\\.json$";
            };
            yamlfix = {
              enable = true;
              entry = "${pkgs.coreutils}/bin/env -u PYTHONHOME -u PYTHONPATH YAMLFIX_PRESERVE_QUOTES=true ${pkgs.yamlfix}/bin/yamlfix";
              types = [ "yaml" ];
              excludes = [ "^home-assistant/configuration\\.yaml$" ];
            };
            shellcheck.enable = true;
          };
        };
      in {
        checks.pre-commit-check = pre-commit-check;

        devShells.default = pkgs.mkShell {
          packages = (with pkgs; [
            expect
            dependabot-cli
            gitleaks
            mkcert
            nssTools
            openssl
            zensical
          ]) ++ pre-commit-check.enabledPackages;

          shellHook = pre-commit-check.shellHook + ''
            export HOMELAB_MKCERT_ROOT="$(${pkgs.mkcert}/bin/mkcert -CAROOT)"

            if [ ! -f "$HOMELAB_MKCERT_ROOT/rootCA.pem" ]; then
              echo "mkcert CA is not installed yet. Run: mkcert -install"
            fi
          '';
        };

        devShell = self.devShells.${system}.default;
      });
}
