#!/usr/bin/env sh

# Building Docker images using Nix on Mac doesn't really work, you need a remote builder for that.
# Remote builders are cool and all, but running a nixos container using Docker for Mac, is easier.
#
# There's a docker-compose file that you can use to run the application using these images.

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
   rm -f /app/nix-build/symfonix-php.tar && nix run --extra-experimental-features \"nix-command flakes\" --option filter-syscalls false .#phpImage.copyTo docker-archive:///app/nix-build/symfonix-php.tar:symfonix-php:latest &&
   rm -f /app/nix-build/symfonix-caddy.tar && nix run --extra-experimental-features \"nix-command flakes\" --option filter-syscalls false .#caddyImage.copyTo docker-archive:///app/nix-build/symfonix-caddy.tar:symfonix-caddy:latest"

docker load < nix-build/symfonix-php.tar
docker load < nix-build/symfonix-caddy.tar

