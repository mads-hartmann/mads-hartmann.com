# computer.mads-hartmann.com

There really is no need for this to be a Jekyll blog, but here we are.

## Starting

```sh
cd sites/computer.mads-hartmann.com
devenv up    # to start jekyll
devenv shell # to get shell, e.g. for updating gems (see below)
```

## Updating gems

Update the version in `Gemfile` and run the following:

```sh
devenv shell
bundle lock # to update Gemfile.lock
bundix      # to update gemset.nix
```