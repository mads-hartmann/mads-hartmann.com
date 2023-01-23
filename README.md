# mads-hartmann.com

TODO: `devenv shell` doesn't work in the blog. I think it might have something to do with Nix not seeing the system certificates as there are a ton in `ls /etc/ssl/*`. Maybe adding ssl as dep works? See https://github.com/NixOS/nixpkgs/issues/3382

This is my mono-repo for everything related to \*.mads-hartmann.com as well as utility tools that don't warrant a separate repository. I wen't with a monorepo for this as that's what most convenient for me. This repository is not meant to be forked, it's open-source in the "look at how it's built so you can copy-paste and modify to your own needs" sense.

## Overview

TODO: Just an overview of the folders

This repository contains many different small projects, which means that the tools and system requirements differ wildly depending on which project I intend to work on. I went with [devenv](https://devenv.sh/) as a way to solve this.

TODO: Describe how devenv/GHA/Gitpod work together

> A GH Action which builds my "devenvs" on main (and a CI check) and caches them somewhere
> Gitpod (and local) integration which just uses that cache
> ===> I suspect this is what cachix does

TODO: Explain reasoning for using default Gitpod image

## Developing

Cd into the appropriate folder and run `devenv up`. Example:

```sh
cd sites/blog.mads-hartmann.com
devenv up
```
