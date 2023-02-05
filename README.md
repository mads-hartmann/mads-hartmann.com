# mads-hartmann.com

This is my mono-repo for everything related to \*.mads-hartmann.com as well as utility tools that don't warrant a separate repository. I went with a monorepo for this as that's what most convenient for me. This repository is not meant to be forked, it's open-source in the "look at how it's built so you can copy-paste and modify to your own needs" sense.

## Overview

This repository contains many different small projects, which means that the tools and system requirements differ wildly depending on which project I intend to work on. I went with [devenv](https://devenv.sh/) as a way to solve this.

## Developing

Cd into the appropriate folder and run `devenv up`. Example:

```sh
cd sites/blog.mads-hartmann.com
devenv up
```
