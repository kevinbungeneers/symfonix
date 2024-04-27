{ pkgs }:

let
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
in
  pkgs.writeShellScript "start-caddy.sh" ''
    mkcert -CAROOT

    if [[ ! -f $DEVSHELL_STATE_DIR/data/mkcert/hash || "$(cat $DEVSHELL_STATE_DIR/data/mkcert/hash)" != "${hash}" ]]; then
      mkdir -p $DEVSHELL_STATE_DIR/data/mkcert

      echo "${hash}" > $DEVSHELL_STATE_DIR/data/mkcert/hash

      pushd $DEVSHELL_STATE_DIR/data/mkcert > /dev/null

      PATH="${pkgs.nssTools}/bin:$PATH" ${pkgs.mkcert}/bin/mkcert ${domainList} 2> /dev/null

      popd > /dev/null
    fi

    XDG_DATA_HOME=$DEVSHELL_STATE_DIR/data XDG_CONFIG_HOME=$DEVSHELL_STATE_DIR/config exec ${pkgs.caddy}/bin/caddy run --config ${caddyFile} --adapter caddyfile
  ''