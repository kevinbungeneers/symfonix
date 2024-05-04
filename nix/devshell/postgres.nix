{ pkgs, lib }:

let
  config = {
    package = pkgs.postgresql_16;
    databaseName = "symfonix";
    settings = {
      "listen_addresses" = "127.0.0.1";
      "port" = 5432;
    };
  };

  toStr = value:
    if true == value then
      "yes"
    else if false == value then
      "no"
    else if lib.isString value then
      "'${lib.replaceStrings [ "'" ] [ "''" ] value}'"
    else
      toString value;

  postgresConfFile = pkgs.writeText "postgresql.conf" ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${n} = ${toStr v}") config.settings)}
  '';

  setupInitialDatabases = ''
    # Create initial databases
    dbAlreadyExists="$(
      echo "SELECT 1 as exists FROM pg_database WHERE datname = '${config.databaseName}';" | \
      psql --dbname postgres | \
      ${pkgs.gnugrep}/bin/grep -c 'exists = "1"' || true
    )"
    echo $dbAlreadyExists
    if [ 1 -ne "$dbAlreadyExists" ]; then
      echo "Creating database: ${config.databaseName}"
      echo 'create database "${config.databaseName}";' | psql --dbname postgres
    fi
  '';

  setupPostgres = pkgs.writeShellScriptBin "setup-postgres" ''
    set -euo pipefail
    export PATH=${config.package}/bin:${pkgs.coreutils}/bin

    POSTGRES_RUN_INITIAL_SCRIPT="false"
    if [[ ! -d "$PGDATA" ]]; then
      initdb --locale=C --encoding=UTF8
      POSTGRES_RUN_INITIAL_SCRIPT="true"
      echo
      echo "PostgreSQL initdb process complete."
      echo
    fi

    cp ${postgresConfFile} "$PGDATA/postgresql.conf"

    if [[ "$POSTGRES_RUN_INITIAL_SCRIPT" = "true" ]]; then
      echo
      echo "PostgreSQL is setting up the initial database."
      echo
      OLDPGHOST="$PGHOST"
      PGHOST=$(mktemp -d "$DEVSHELL_ROOT/pg-init-XXXXXX")

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

  startPostgres = pkgs.writeShellScript "start-postgres.sh" ''
    set -euo pipefail
    ${setupPostgres}/bin/setup-postgres
    exec ${config.package}/bin/postgres -c unix_socket_directories=$PGHOST
  '';
in
{
  processes.postgres.exec = startPostgres;
  buildInputs = [ config.package ];
}