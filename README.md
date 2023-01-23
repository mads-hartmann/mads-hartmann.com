# mads-hartmann.com

This is my mono-repo for everything related to \*.mads-hartmann.com as well as utility tools that don't warrant a separate repository. I wen't with a monorepo for this as that's what most convenient for me. This repository is not meant to be forked, it's open-source in the "look at how it's built so you can copy-paste and modify to your own needs" sense.

## Developing

This repository contains many different small projects, which means that the tools and system requirements differ wildly depending on which project I intend to work on. I went with [devenv](https://devenv.sh/) as a way to solve this.

TODO: Describe how Bundix is used:

> A GH Action which builds my "devenvs" on main (and a CI check) and caches them somewhere
> Gitpod (and local) integration which just uses that cache
> ===> I suspect this is what cachix does

Manual for now:

```sh
# Nix is part of the default Gitpod image
# sh <(curl -L https://nixos.org/nix/install) --daemon

# Cachix is part of the default Gitpod image
# nix profile install nixpkgs#cachix

cachix use devenv
yes | nix profile install github:cachix/devenv/v0.5
```
