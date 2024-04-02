{ pkgs, ... }:

let
  php83WithExtensions = { extensions, extraConfig }: with pkgs; (php83.buildEnv {
    extensions = extensions;
    extraConfig = ''
      expose_php = 0
      date.timezone = UTC
      apc.enable_cli = 1
      session.use_strict_mode = 1
      zend.detect_unicode = 0

      realpath_cache_size = 4096K
      realpath_cache_ttl = 600
      opcache.interned_strings_buffer = 16
      opcache.max_accelerated_files = 20000
      opcache.memory_consumption = 256
      opcache.enable_file_override = 1

      ${extraConfig}
    '';
  });

  prod = php83WithExtensions {
    extensions = { enabled, all }: enabled ++ (with all; [
      apcu
    ]);
    extraConfig = ''
      memory_limit = 512M
      fastcgi.logging = Off
    '';
  };

  dev = php83WithExtensions {
    extensions = { enabled, all }: enabled ++ (with all; [
      apcu
      xdebug
    ]);
    extraConfig = ''
      memory_limit = 1G
      xdebug.mode = debug
    '';
  };
in
{
  inherit prod dev;
  composer = pkgs.php83Packages.composer.override { php = dev; };
}