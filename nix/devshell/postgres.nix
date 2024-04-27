{ pkgs, package }:
let
  # TODO: Make this configurable
  databaseName = "symfonix";

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
    export PATH=${package}/bin:${pkgs.coreutils}/bin

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
in
  pkgs.writeShellScript "start-postgres.sh" ''
    set -euo pipefail
    ${setupPostgres}/bin/setup-postgres
    exec ${package}/bin/postgres
  ''