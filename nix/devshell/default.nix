{ pkgs, phpPkgs, ... }:

let
  php = phpPkgs.dev;
  postgrespkg = pkgs.postgresql_16;

  phpFpm = pkgs.callPackage ./php-fpm.nix { php = php; };
  postgres = pkgs.callPackage ./postgres.nix { package = postgrespkg; };
  caddy = pkgs.callPackage ./caddy.nix {};

  procFile = pkgs.writeTextFile {
    name = "Procfile";
    text = ''
      caddy: exec ${caddy}
      php-fpm: exec ${phpFpm}
      postgresql: exec ${postgres}
      npm-watch: npm run watch
    '';
  };

  # Had to wrap overmind so that I could set the root directory. It defaults to the dir where the procfile is located
  # and there's no env var to override this dir value, for some reason.
  # The wrapping also allows me to generate SSL certificates when the server's started, instead of in the shellHook.
  overmind = pkgs.writeShellScriptBin "overmind" ''
    carootdir=$(mkcert -CAROOT)
    if [[ ! -f "$carootdir/rootCA.pem" ]]; then
      PATH="${pkgs.nssTools}/bin:$PATH" ${pkgs.mkcert}/bin/mkcert -install
    fi

    extraParams=""
    case "$@" in
      'start')
        ;;
      's')
        extraParams="--root $PROJECT_DIR"
        ;;
    esac

    OVERMIND_PROCFILE=${procFile} ${pkgs.overmind}/bin/overmind "$@" $extraParams
  '';
in
{
  default = pkgs.mkShell {
    buildInputs = [
      overmind
      postgrespkg
      php
      phpPkgs.composer
      pkgs.nodejs_20
      pkgs.dive
    ];
  };
}
