{ pkgs, nix2containerPkgs, phpPkgs, ... }:

let
  project = phpPkgs.prod.buildComposerProject(finalAttrs: {
    pname = "symfonix";
    version = "1.0.0";

    src = ./..;
    vendorHash = "sha256-eNe0MYPOech3Vk5Wkp7zvR8orKE/AQ0A4jDu5hYNMPk=";

    frontend = pkgs.buildNpmPackage({
      inherit (finalAttrs) pname version src;
      npmDepsHash = "sha256-xk+bb5Pds7gYaxzCrVONjMaJ8ycoOgFsf+mc4WDUIYc=";
      nodejs = pkgs.nodejs_20;
      postInstall = ''
        cp -R public/build $out
      '';
    });

    # TODO: Is postInstall the right place for this?
    postInstall = ''
      mkdir -p $out/share/php/symfonix/var/{cache,log}
      cd $out/share/php/symfonix
      composer dump-autoload --classmap-authoritative --no-dev
      composer dump-env prod
      composer run-script --no-dev post-install-cmd
      chmod +x bin/console
      cp -R ${finalAttrs.frontend}/build $out/share/php/symfonix/public/build
    '';
  });

  user = {
    name = "symfonix";
    id = 1000;
  };
  group = {
    name = "symfonix";
    id = 1000;
  };

  mkEtc = {name, extra }: pkgs.runCommand name { } ''
    mkdir -p $out/etc/pam.d

    echo "root:x:0:0:System administrator:/dev/null:noshell" > $out/etc/passwd
    echo "${user.name}:x:${toString user.id}:${toString group.id}::/dev/null:noshell" >> $out/etc/passwd

    echo "root:!x:::::::" > $out/etc/shadow
    echo "${user.name}:!x:::::::" >> $out/etc/shadow

    echo "root:x:0:" > $out/etc/group
    echo "${group.name}:x:${toString group.id}:" >> $out/etc/group

    cat > $out/etc/pam.d/other <<EOF
    account sufficient pam_unix.so
    auth sufficient pam_rootok.so
    password requisite pam_unix.so nullok sha512
    session required pam_unix.so
    EOF

    touch $out/etc/login.defs

    ${extra}
  '';

  mkVar = pkgs.runCommand "container-var" { } ''
    mkdir -p $out/var/run/php
  '';

  mkCaddyConfig = pkgs.runCommand "caddy-config" { } ''
    mkdir -p $out/srv/caddy/{data,config}
  '';

  publicFiles = pkgs.runCommand "public" { } ''
    mkdir -p $out/share/php/symfonix
    cp -R ${project}/share/php/symfonix/public $out/share/php/symfonix/public
  '';

  caddyEtc = ''
    mkdir -p $out/etc/caddy

    cat <<EOT >> $out/etc/caddy/Caddyfile
    {\$SERVER_NAME} {
      log
      root * /share/php/symfonix/public
      php_fastcgi unix//var/run/php/php-fpm.sock
      encode zstd gzip
      file_server
    }
    EOT
  '';

  phpEtc = ''
    mkdir -p $out/etc/php/php-fpm.d

    cat <<EOT >> $out/etc/php/php-fpm.d/php-fpm.conf
    [global]
    daemonize = no
    error_log = /proc/self/fd/2
    log_limit = 8192

    [www]
    access.log = /proc/self/fd/2
    clear_env = no
    catch_workers_output = yes
    decorate_workers_output = no
    listen = /var/run/php/php-fpm.sock
    listen.mode = 0666
    ping.path = /ping

    pm = dynamic
    pm.max_children = 5
    pm.start_servers = 2
    pm.min_spare_servers = 1
    pm.max_spare_servers = 3
    EOT
  '';
in
{
  caddyImage = nix2containerPkgs.nix2container.buildImage {
    name = "symfonix-caddy";
    tag = "latest";
    maxLayers = 99;
    copyToRoot = [
      publicFiles
      mkVar
      mkCaddyConfig
      (mkEtc { name = "caddy-etc"; extra = caddyEtc; })
    ];
    perms = [
      {
        path = mkVar;
        regex = "/var/run/php";
        mode = "0755";
        uid = user.id;
        gid = group.id;
        uname = user.name;
        gname = group.name;
      }
      {
        path = mkCaddyConfig;
        regex = "/srv/caddy";
        mode = "0755";
        uid = user.id;
        gid = group.id;
        uname = user.name;
        gname = group.name;
      }
      {
        path = publicFiles;
        regex = "/share/php/symfonix";
        mode = "0755";
        uid = user.id;
        gid = group.id;
        uname = user.name;
        gname = group.name;
      }
    ];
    config = {
      User = "${user.name}";
      WorkingDir = "/share/php/symfonix";
      Cmd = [ "${pkgs.caddy}/bin/caddy" "run" "--config" "/etc/caddy/Caddyfile" "--adapter" "caddyfile" ];
      Env = [
        "XDG_CONFIG_HOME=/srv/caddy/config"
        "XDG_DATA_HOME=/srv/caddy/data"
      ];
    };
  };

  phpImage = nix2containerPkgs.nix2container.buildImage {
    name = "symfonix-php";
    tag = "latest";
    maxLayers = 99;
    copyToRoot = [
      project
      (mkEtc { name = "php-etc"; extra = phpEtc; })
      mkVar
    ];
    perms = [
      {
        path = mkVar;
        regex = "/var/run/php";
        mode = "0755";
        uid = user.id;
        gid = group.id;
        uname = user.name;
        gname = group.name;
      }
      {
        path = project;
        regex = "/share/php/symfonix";
        mode = "0755";
        uid = user.id;
        gid = group.id;
        uname = user.name;
        gname = group.name;
      }
    ];
    config = {
      User = "${user.name}";
      WorkingDir = "/share/php/symfonix";
      Cmd = [ "${phpPkgs.prod}/bin/php-fpm" "-y" "/etc/php/php-fpm.d/php-fpm.conf" ];
    };
  };
}