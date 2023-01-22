# blog.mads-hartmann.com

Uses devenv. Uses [bundix](https://github.com/nix-community/bundix) so that Nix can manage the gems (TOOD: The purpose is to allow me use the nix cache so that I don't have to compile gems)

```
cd sites/blog.mads-hartmann.com
devenv shell
devenv up
```

## Updating gems

Update the version in `Gemfile` and run the following:

```sh
devenv shell
bundle lock # to update Gemfile.lock
bundix      # to update gemset.nix
```
