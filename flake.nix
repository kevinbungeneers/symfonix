{
  description = "Nix setup for Symfony projects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix2container.url = "github:nlewo/nix2container";
  };

  outputs = { self, nixpkgs, nix2container, flake-utils }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      nix2containerPkgs = nix2container.packages.${system};
      phpPkgs = (import ./nix/php.nix { inherit pkgs; });
    in {
      packages = (import ./nix/container.nix {
        inherit pkgs nix2containerPkgs;
        inherit (phpPkgs) phpPkgs;
      });

      devShells.default = (import ./nix/devshell {
        inherit pkgs;
        inherit (phpPkgs) phpPkgs;
        inherit (pkgs) lib;
      });
    }
  );
}