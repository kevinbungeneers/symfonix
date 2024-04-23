{ pkgs, ... }:

let
  php = (import ./php.nix { inherit pkgs; });

  # TODO: make this configurable
  domainList = pkgs.lib.concatStringsSep " " [
    "symfonix.localhost"
  ];

  hash = builtins.hashString "sha256" domainList;

  caddyFile = pkgs.writeTextFile {
    name = "Caddyfile";
    text = ''
      symfonix.localhost {
        log
      	root * {$PROJECT_DIR}/public
      	php_fastcgi unix///{$DEVSHELL_STATE_DIR}/data/php/php-fpm.sock
      	encode zstd gzip
      	file_server
      	tls {$DEVSHELL_STATE_DIR}/data/mkcert/symfonix.localhost.pem {$DEVSHELL_STATE_DIR}/data/mkcert/symfonix.localhost-key.pem
      }
    '';
  };

  fpmConfig = pkgs.writeTextFile {
    name = "php-fpm.conf";
    text = ''
      [global]
      daemonize = no
      error_log = syslog
      log_level = notice

      [www]
      listen = ''${DEVSHELL_STATE_DIR}/data/php/php-fpm.sock
      listen.mode = 0666
      ping.path = /ping
      clear_env = no
      pm = "dynamic";
      pm.max_children = 5;
      pm.start_servers = 2;
      pm.min_spare_servers = 1;
      pm.max_spare_servers = 5;
    '';
  };

  startPhpFpm = pkgs.writeShellScript "start-php-fpm" ''
    mkdir -p $DEVSHELL_STATE_DIR/data/php
    exec ${php.dev}/bin/php-fpm -y ${fpmConfig}
  '';

  startCaddy = pkgs.writeShellScript "start-caddy.sh" ''
    mkcert -CAROOT

    if [[ ! -f $DEVSHELL_STATE_DIR/data/mkcert/hash || "$(cat $DEVSHELL_STATE_DIR/data/mkcert/hash)" != "${hash}" ]]; then
      mkdir -p $DEVSHELL_STATE_DIR/data/mkcert

      echo "${hash}" > $DEVSHELL_STATE_DIR/data/mkcert/hash

      pushd $DEVSHELL_STATE_DIR/data/mkcert > /dev/null

      PATH="${pkgs.nssTools}/bin:$PATH" ${pkgs.mkcert}/bin/mkcert ${domainList} 2> /dev/null

      popd > /dev/null
    fi

    XDG_DATA_HOME=$DEVSHELL_STATE_DIR/data XDG_CONFIG_HOME=$DEVSHELL_STATE_DIR/config exec ${pkgs.caddy}/bin/caddy run --config ${caddyFile} --adapter caddyfile
  '';

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

  procFile = pkgs.writeTextFile {
    name = "Procfile";
    text = ''
      caddy: exec ${startCaddy}
      php-fpm: exec ${startPhpFpm}
      npm-watch: npm run watch
    '';
  };
in
{
  default = pkgs.mkShell {
    buildInputs = [
      overmind
      php.dev
      php.composer
      pkgs.postgresql_16
      pkgs.nodejs_20
      pkgs.dive
    ];
  };
}
