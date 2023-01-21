# devens

WIP: Just playing around with devenv for now.

This folder contains reusable [devenv](https://devenv.sh/) for various tasks; they are fragments of developer environments tailored to my needs that I compose as need in other repositories.

## Overview

- **scripting** - General purpose tools that I usually reach for in ad-hoc shell sessions or smaller shell scripts.
- **kubernetes** - TODO
- **terraform** - TODO

## Using these devens

See [./demo/remote/devenv.yaml](./demo/remote/devenv.yaml).

## Working on the devens

I haven't made installed devenv as part of the Gitpod setup for this repository yet as I'm just playing around for now.

So you'll have to [install devenv manually](https://devenv.sh/getting-started/).

```sh
# First cachix
nix-env -iA cachix -f https://cachix.org/api/v1/install
cachix use devenv
# Then devenv
nix-env -if https://github.com/cachix/devenv/tarball/v0.1
```
