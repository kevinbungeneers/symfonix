# The Symfonix Experiment
An exciting exploration into the integration of Nix and a selection of diverse development tools into a standard project lifecycle.

## Goals
- A reproducible development environment that doesn't rely on running virtual machines or containers.
- The ability to pin dependencies so that the same software is used from dev to production.
- The right tool for the job: combine several tools that do a singular thing well. Avoid abstractions!

## Tools used

### Nix
[Nix](https://nixos.org) is used for two things:
- managing a devshell that contains (pinned) packages like PHP and Node
- building Docker images

This allows me to have a reproducible development environment that runs local, yet isolated +
include those same packages into Docker images.

### Direnv
[Direnv](https://direnv.net) is used to automatically start the devshell when you `cd` into the project dir, offering a more seamless experience. There's some custom stuff happening in `.envrc` that makes sure your environment is set up properly.

### Overmind
[Overmind](https://github.com/DarthSim/overmind) is a process manager that runs the tasks defined in the `Procfile`. Think `docker compose`, but without Docker.

## Why PHP and Symfony?
PHP setups require a bit more work than building a static binary with Go. There's more weird stuff to figure out this way, making it more suitable
for an experiment like this.