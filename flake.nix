{
  description = "Nix setup for Symfony projects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: flake-utils.lib.eachDefaultSystem (system:
    let pkgs = nixpkgs.legacyPackages.${system}; in {
      packages = (import ./nix/container.nix { inherit pkgs; });
      devShells = (import ./nix/devshell.nix { inherit pkgs; });
    }
  );
}