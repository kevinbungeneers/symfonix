{ pkgs, ... }:

let
  php = (import ./php.nix { inherit pkgs; });

  # TODO: make this configurable
  domainList = pkgs.lib.concatStringsSep " " [
    "symfonix.localhost"
  ];

  databaseName = "symfonix";

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

  postgresConf = pkgs.writeTextFile {
    name = "postgresql.conf";
    text = ''
      listen_addresses = '127.0.0.1'
      port = 5432
    '';
  };

  setupInitialDatabases = ''
    # Create initial databases
    dbAlreadyExists="$(
      echo "SELECT 1 as exists FROM pg_database WHERE datname = '${databaseName}';" | \
      psql --dbname postgres | \
      ${pkgs.gnugrep}/bin/grep -c 'exists = "1"' || true
    )"
    echo $dbAlreadyExists
    if [ 1 -ne "$dbAlreadyExists" ]; then
      echo "Creating database: ${databaseName}"
      echo 'create database "${databaseName}";' | psql --dbname postgres
    fi
  '';

  setupPostgres = pkgs.writeShellScriptBin "setup-postgres" ''
    set -euo pipefail
    export PATH=${pkgs.postgresql_16}/bin:${pkgs.coreutils}/bin

    POSTGRES_RUN_INITIAL_SCRIPT="false"
    if [[ ! -d "$PGDATA" ]]; then
      initdb --locale=C --encoding=UTF8
      POSTGRES_RUN_INITIAL_SCRIPT="true"
      echo
      echo "PostgreSQL initdb process complete."
      echo
    fi

    cp ${postgresConf} "$PGDATA/postgresql.conf"

    if [[ "$POSTGRES_RUN_INITIAL_SCRIPT" = "true" ]]; then
      echo
      echo "PostgreSQL is setting up the initial database."
      echo
      OLDPGHOST="$PGHOST"
      PGHOST=$(mktemp -d "$DEVSHELL_STATE_DIR/pg-init-XXXXXX")

      function remove_tmp_pg_init_sock_dir() {
        if [[ -d "$1" ]]; then
          rm -rf "$1"
        fi
      }
      trap "remove_tmp_pg_init_sock_dir '$PGHOST'" EXIT

      pg_ctl -D "$PGDATA" -w start -o "-c unix_socket_directories=$PGHOST -c listen_addresses= -p 5432"
      ${setupInitialDatabases}

      pg_ctl -D "$PGDATA" -m fast -w stop
      remove_tmp_pg_init_sock_dir "$PGHOST"
      PGHOST="$OLDPGHOST"
      unset OLDPGHOST
    fi
    unset POSTGRES_RUN_INITIAL_SCRIPT
  '';

  startPostgresql = pkgs.writeShellScript "start-postgres.sh" ''
    set -euo pipefail
    ${setupPostgres}/bin/setup-postgres
    exec ${pkgs.postgresql_16}/bin/postgres
  '';

  procFile = pkgs.writeTextFile {
    name = "Procfile";
    text = ''
      caddy: exec ${startCaddy}
      php-fpm: exec ${startPhpFpm}
      postgresql: exec ${startPostgresql}
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
      php.dev
      php.composer
      pkgs.postgresql_16
      pkgs.nodejs_20
      pkgs.dive
    ];
  };
}
