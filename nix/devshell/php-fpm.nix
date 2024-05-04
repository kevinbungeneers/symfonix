{ pkgs, phpPkgs, lib }:
let
  config = {
    package = phpPkgs.dev;
    global = {
      "daemonize" = "no";
      "error_log" = "syslog";
      "log_level" = "notice";
    };
    pools = {
      "www" = {
        "listen" = ''''${DEVSHELL_ROOT}/data/php-fpm/www.sock'';
        "listen.mode" = "0666";
        "ping.path" = "/ping";
        "clear_env" = "no";
        "pm" = "dynamic";
        "pm.max_children" = 5;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 5;
      };
    };
  };

  fpmConfigFile = pool: poolOpts: pkgs.writeText "phpfpm-${pool}.conf" ''
    [global]
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${n} = ${toString v}") config.global)}
    [${pool}]
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${n} = ${toString v}") poolOpts)}
  '';

  startScript = pool: poolOpts: ''
    set -euo pipefail

    if [[ ! -d "$DEVSHELL_ROOT/data/php-fpm" ]]; then
      mkdir -p "$DEVSHELL_ROOT/data/php-fpm"
    fi

    exec ${config.package}/bin/php-fpm -F -y ${fpmConfigFile pool poolOpts}
  '';
in
{
  processes = lib.mapAttrs' (pool: poolOpts: lib.nameValuePair "phpfpm-${pool}" {
    exec = startScript pool poolOpts;
  }) config.pools;

  buildInputs = [
    phpPkgs.composer
  ];
}