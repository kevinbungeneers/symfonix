{ pkgs }:

let
  config = {
    package = pkgs.caddy;
    virtualHosts = {
      "symfonix.localhost" = {
        aliases = [];
        config = ''
          log
          root * {$PROJECT_ROOT}/public
          php_fastcgi unix///{$DEVSHELL_ROOT}/data/php-fpm/www.sock
          encode zstd gzip
          file_server
          tls {$DEVSHELL_ROOT}/data/mkcert/symfonix.localhost.pem {$DEVSHELL_ROOT}/data/mkcert/symfonix.localhost-key.pem
        '';
      };
    };
  };

  vhostConfigFromAttrs = vhostName: vhostAttrs: ''
    ${vhostName} ${builtins.concatStringsSep " " vhostAttrs.aliases} {
      ${vhostAttrs.config}
    }
  '';

  caddyFile = pkgs.writeText "Caddyfile" (
    builtins.concatStringsSep "\n" (pkgs.lib.mapAttrsToList vhostConfigFromAttrs config.virtualHosts)
  );

  domainList = vhostName: vhostAttrs: (
    [ vhostName ] ++ vhostAttrs.aliases
  );

  domainListStr = builtins.concatStringsSep " " (builtins.concatLists (pkgs.lib.mapAttrsToList domainList config.virtualHosts));

  hash = builtins.hashString "sha256" domainListStr;

  caddyStartScript = pkgs.writeShellScript "start-caddy.sh" ''
    if [[ ! -f $DEVSHELL_ROOT/data/mkcert/hash || "$(cat $DEVSHELL_ROOT/data/mkcert/hash)" != "${hash}" ]]; then
      mkdir -p $DEVSHELL_ROOT/data/mkcert
      echo "${hash}" > $DEVSHELL_ROOT/data/mkcert/hash
      pushd $DEVSHELL_ROOT/data/mkcert > /dev/null
      PATH="${pkgs.nssTools}/bin:$PATH" ${pkgs.mkcert}/bin/mkcert ${domainListStr}
      popd > /dev/null
    fi

    XDG_DATA_HOME=$DEVSHELL_ROOT/data XDG_CONFIG_HOME=$DEVSHELL_ROOT/config exec ${config.package}/bin/caddy run --config ${caddyFile} --adapter caddyfile
  '';
in {
   processes.caddy.exec = caddyStartScript;
   buildInputs = [];
}