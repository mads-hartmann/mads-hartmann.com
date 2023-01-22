# mads-hartmann.com

**👷‍♂️ WIP 🚜**: I'm slowly evolving this into a mono-repo containing all the code related to all my \*.mads-hartmann.com sites. Things will be quite messy and unfinished for a while

Manual for now:

```sh
# Nix is part of the default Gitpod image
# sh <(curl -L https://nixos.org/nix/install) --daemon

# Cachix is part of the default Gitpod image
# nix profile install nixpkgs#cachix

cachix use devenv
nix profile install github:cachix/devenv/v0.5
```
