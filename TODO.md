## devenv CI <-> Gitpod

I run `devenv ci` in GitHub Actions in [./.github/workflows/devenv-check.yml](./.github/workflows/devenv-check.yml). I want to be able to re-use the nix store so I don't ever have to build any derivations when I start my Gitpod workspaces. This is sort of an alternative to Gitpod Prebuilds with the benefit that I only need to download the files when I needed them (you only get a single prebuild per repository) which is useful in a heterogeneous monorepo like this one.

What I still need to do:

1. I will need a cache that can be shared by GH and Gitpod. I think I can use [Cachix](https://www.cachix.org/) for this.
2. I need to configure GH to use and populate that cache
3. I need to configure Gitpod to use that cache

👆 sites/blog.mads-hartmann.com is a good candidate to test this approach. I use Bundix to have Nix manage my gems. If the above works I would see that `devenv up` just downloads derivations into the store rather than building them.

(Once this is done and works, update the README to explain this approach. Also note that I use the default Gitpod workspace image because that boots **really** fast. In all of this I have optimised for quick boot times at the expense of then having to wait a bit once the workspace is started - but I prefer that because then I will at leave have en editor open and I can start working.)
