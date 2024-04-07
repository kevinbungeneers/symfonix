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
    in {
      packages = (import ./nix/container.nix { inherit pkgs nix2containerPkgs; });
      devShells = (import ./nix/devshell.nix { inherit pkgs; });
    }
  );
}