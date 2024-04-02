{ pkgs, ... }:

let
  php = (import ./php.nix { inherit pkgs; });
in
{
  builderImage = pkgs.dockerTools.buildLayeredImage {
    name = "symfonix-builder";
    tag = "latest";
    contents =  [
      php.composer
      pkgs.coreutils
      pkgs.bash
      pkgs.nodejs_20
      pkgs.shadow
      pkgs.cacert
    ];
    config = {
      Env = [ "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];
    };
  };

  phpBaseImage = pkgs.dockerTools.buildLayeredImage {
    name = "symfonix-php-base";
    tag = "latest";
    contents = [ php.prod pkgs.cacert ];
    config = {
      Env = [ "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];
    };
  };

  caddyBaseImage = pkgs.dockerTools.buildLayeredImage {
    name = "symfonix-caddy-base";
    tag = "latest";
    contents = [ pkgs.caddy pkgs.cacert ];
    config = {
      Env = [ "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];
    };
  };
}