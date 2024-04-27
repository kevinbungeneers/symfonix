{ pkgs, php }:
let
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
in
  pkgs.writeShellScript "start-php-fpm" ''
    mkdir -p $DEVSHELL_STATE_DIR/data/php
    exec ${php}/bin/php-fpm -y ${fpmConfig}
  ''