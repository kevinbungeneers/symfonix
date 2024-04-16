{ pkgs, ... }:

let
  php = (import ./php.nix { inherit pkgs; });

  caddyFile = pkgs.writeTextFile {
    name = "Caddyfile";
    text = ''
      symfonix.localhost {
        log
      	root * {$PROJECT_DIR}/public
      	php_fastcgi unix///{$DEVSHELL_STATE_DIR}/php-fpm/data/php-fpm.sock
      	encode zstd gzip
      	file_server
      	tls {$DEVSHELL_STATE_DIR}/mkcert/symfonix.localhost.pem {$DEVSHELL_STATE_DIR}/mkcert/symfonix.localhost-key.pem
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
      listen = ''${DEVSHELL_STATE_DIR}/php-fpm/data/php-fpm.sock
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

  procFile = pkgs.writeTextFile {
    name = "Procfile";
    text = ''
      caddy: XDG_DATA_HOME=$DEVSHELL_STATE_DIR/caddy/data XDG_CONFIG_HOME=$DEVSHELL_STATE_DIR/caddy/config exec ${pkgs.caddy}/bin/caddy run --config ${caddyFile} --adapter caddyfile
      php-fpm: exec ${php.dev}/bin/php-fpm -y ${fpmConfig}
    '';
  };

  # TODO: make this configurable
  domainList = pkgs.lib.concatStringsSep " " [
    "symfonix.localhost"
  ];

  hash = builtins.hashString "sha256" domainList;
in
{
  default = pkgs.mkShell {
    buildInputs = [
      pkgs.overmind
      php.dev
      php.composer
      pkgs.postgresql_16
      pkgs.nodejs_20
      pkgs.dive
    ];

    # TODO: Not sure if the shell hook is the right place to init certificate related stuff?
    #       Instead of setting the $CAROOT env var, I could just as well do something like mkcert -CAROOT to check
    #       if mkcert -install has been run.
    shellHook = ''
      export OVERMIND_PROCFILE=${procFile}

      mkdir -p $PWD/.devshell/mkcert

      export CAROOT=$PWD/.devshell/mkcert

      if [[ ! -f $PWD/.devshell/mkcert/rootCA.pem ]]; then
        PATH="${pkgs.nssTools}/bin:$PATH" ${pkgs.mkcert}/bin/mkcert -install
      fi

      if [[ ! -f $PWD/.devshell/mkcert/hash || "$(cat $PWD/.devshell/mkcert/hash)" != "${hash}" ]]; then
        echo "${hash}" > $PWD/.devshell/mkcert/hash

        pushd $PWD/.devshell/mkcert > /dev/null

        PATH="${pkgs.nssTools}/bin:$PATH" ${pkgs.mkcert}/bin/mkcert ${domainList} 2> /dev/null

        popd > /dev/null
      fi
    '';
  };
}
