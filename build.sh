#!/usr/bin/env sh

# Building Docker images using Nix on Mac doesn't really work, you need a remote builder for that.
# Remote builders are cool and all, but running a nixos container using Docker for Mac, is easier.

set -eux

docker run -it --rm \
  --platform linux/amd64 \
  --privileged \
  --name symfonix-builder \
  -w /app \
  -v .:/app \
  nixos/nix:latest \
  sh -c \
  "mkdir -p /app/nix-build &&
   rm -f /app/nix-build/symfonix-php.tar && nix run --extra-experimental-features \"nix-command flakes\" --option filter-syscalls false .#php.copyTo docker-archive:///app/nix-build/symfonix-php.tar:registry.bungerous.be/kevin/symfony-nix/symfonix-php:latest &&
   rm -f /app/nix-build/symfonix-caddy.tar && nix run --extra-experimental-features \"nix-command flakes\" --option filter-syscalls false .#caddy.copyTo docker-archive:///app/nix-build/symfonix-caddy.tar:registry.bungerous.be/kevin/symfony-nix/symfonix-caddy:latest"

docker load < nix-build/symfonix-php.tar
docker load < nix-build/symfonix-caddy.tar

