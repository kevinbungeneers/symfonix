{ pkgs, ... }:

let
  php = (import ./php.nix { inherit pkgs; });
in
{
  default = pkgs.mkShell {
    buildInputs = [
      pkgs.overmind
      php.dev
      php.composer
      pkgs.caddy
      pkgs.postgresql_16
      pkgs.nodejs_20
      pkgs.dive
    ];
  };
}
