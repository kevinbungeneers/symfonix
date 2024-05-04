{ pkgs, phpPkgs, lib, ... }:

let
  caddy = import ./caddy.nix { inherit pkgs; };
  phpFpm = import ./php-fpm.nix { inherit pkgs phpPkgs lib; };
  postgres = import ./postgres.nix { inherit pkgs lib; };
  nodejs = import ./nodejs.nix { inherit pkgs; };

  overmind = import ./overmind.nix {
    inherit pkgs lib;
    processes = caddy.processes
      // phpFpm.processes
      // postgres.processes
      // nodejs.processes;
  };
in
  pkgs.mkShell {
    buildInputs = caddy.buildInputs
      ++ phpFpm.buildInputs
      ++ postgres.buildInputs
      ++ overmind.buildInputs
      ++ nodejs.buildInputs;
  }