# Development

A single root [devenv](https://devenv.sh/) configuration supplies all tools, wherever
in the repository you work. Nix owns the tools and locked dependencies; Bazel
tracks builds and tests. Makefiles provide entry points and development servers.
The environment supports Apple Silicon macOS and x86-64 Linux; the Bazel integration
has been exercised on Linux. CI uses the same Nix expressions and Bazel targets.

## First-time setup

Install [Determinate Nix](https://docs.determinate.systems/getting-started/) if
`nix --version` does not work. An existing installation is sufficient. From the
repository root:

```sh
./scripts/bootstrap-dev.sh
devenv shell
make setup
```

The bootstrap installs pinned devenv 2.3.1, direnv, and modern Bash into your
standard Nix user profile, following [devenv's installation guide](https://devenv.sh/getting-started/).
It builds the tools before replacing their profile entries, so repeating setup
updates these three tools without adding duplicate entries. Nix normally puts
this profile on `PATH`. If your shell does not yet see the tools, open a new
terminal. The first environment activation can take several minutes.

The environment provides Bazel 8, Node 24, Ruby 3.3.11, Terraform 1.16.5, native gem build
tools, Make, watchexec, actionlint, Bash, Git, GitHub CLI, AWS CLI, curl, Python,
jq, gawk, direnv, kubectl, kubectx, and stern. Ruby uses devenv's built-in version
selector with the pinned `nixpkgs-ruby` input. Nix builds the blog's gem environment
from `Gemfile.lock` and the generated `gemset.nix`. Terraform 1.16.5 is the only
supported version, used in development, CI and deployment.

Determinate manages `/etc/nix/nix.conf`; any personal Nix settings belong in
`/etc/nix/nix.custom.conf`. This setup needs no edits to either file.

## Activate once

Run `devenv shell` from the repository root, then change to any project directory
inside that shell. All tools remain available. Nix realizes the pinned Jekyll gem
environment when entering the shell; site builds realize their locked npm dependencies.
Entering the shell does not build sites or start servers.

For automatic activation, add the appropriate direnv hook to your shell:

```sh
# Bash: add to ~/.bashrc
eval "$(direnv hook bash)"
# Zsh: use this in ~/.zshrc instead
eval "$(direnv hook zsh)"
```

Review the root `.envrc` and run `direnv allow` once at the root. The same
root environment stays active in every subfolder. Avoid nesting `devenv shell`
sessions when using direnv.

## Build, check, and run

Run `make` in the root or a project directory to see its targets.

| Directory | Commands | Development server |
| --- | --- | --- |
| Repository root | `make setup`, `make build`, `make check`, `make lint` | `make dev` starts all four |
| `sites/mads-hartmann.com` | `make setup`, `make build`, `make check`, `make lint` | `make dev`, port 8080 |
| `sites/blog.mads-hartmann.com` | `make setup`, `make build`, `make check`, `make lint` | `make dev`, port 4000 |
| `sites/uses.mads-hartmann.com` | `make setup`, `make build`, `make check`, `make lint` | `make dev`, port 8081 |
| `sites/computer.mads-hartmann.com` | `make setup`, `make build`, `make check`, `make lint` | `make dev`, port 8082 |
| `terraform` | `make fmt`, `make lint`, `make check` | None |

You can also invoke a project's Makefile from the root:

```sh
make -C sites/blog.mads-hartmann.com dev
make -C terraform check
```

Each site's own build produces its Markdown alternatives and publishes its
committed `llms.txt`. `scripts/build.sh` invokes Bazel and exports its artifacts to
`.build` for Terraform and previews. Bazel uses immutable Nix dependencies, including
the shared asset fingerprinting packages. There is no npm install during a build action.
See [Bazel builds](builds.md) for individual targets and cache verification.

`make dev` uses watchexec to rebuild and restart a foreground server when source, `llms.txt`,
build scripts, or the shared footer change. Jekyll includes drafts and disables
its disk cache. Its preview output is `.build/blog-preview`, separate from the
production `.build/blog` output. Each `dev` target handles its own build or setup
and starts the server directly under the watcher. Stop servers with Ctrl-C. Avoid
starting root and project servers simultaneously on the same ports.

Override ports with Make variables or environment variables:

```sh
make -C sites/blog.mads-hartmann.com dev BLOG_PORT=4001
HOMEPAGE_PORT=8090 USES_PORT=8091 BLOG_PORT=4001 make dev
```

## Validation

Inside the root devenv shell, choose the check for your change:

| Change | Command from the repository root |
| --- | --- |
| Site content, styles, shared footer or routing | `make check-sites` |
| Terraform | `make -C terraform check` |
| GitHub Actions workflows | `make check-workflows` |
| Full repository | `make check` |

Site checks run `bazel test //...`, which builds declared artifacts and checks generated
pages, Markdown, images, routing, workflows, manifests and deployment logic. A site's
`make check` (or `make lint`) runs these same checks, including cross-site assertions.
For a focused check, use `bazel test //:uses_test` (or homepage, blog, computer).
Preview changed pages at desktop and mobile widths, including light and dark modes.

Terraform checks build the sites, check formatting, validate configuration and run
offline tests. The full repository check also runs workflow linting with actionlint;
root `make lint` runs the same checks as root `make check`.
These checks need no AWS or GitHub credentials. Actual plans and applies use the
authentication described in [Deployment](deployment.md).

For documentation-only changes, check that links, paths and commands match the
repository. Site builds and screenshots are unnecessary unless rendered pages change.

## Configuration and updates

`devenv.nix`, `devenv.yaml`, and the committed `devenv.lock` at the root are the
environment entry points. The YAML uses JSON syntax so the bootstrap and Bazel
can read the same pins. `dev/shared/versions.nix` selects runtime versions, and
`dev/bazel/tools.nix` constructs the shared build tools and dependency environments.
Runnable commands live in Makefiles and repository scripts.

To update tools, edit root input revisions and language versions, bootstrap again
when activation tools change, then run from the root:

```sh
scripts/lock-dev-env.sh
make check
```

Review and commit the resulting root lockfile. After changing blog gem locks, run
`bundix` in the blog directory and commit `gemset.nix` too. CI uses the same build
tool pins; Terraform installation remains explicit in its workflow jobs. Kubernetes utilities are included in the normal environment.

## Local state and cloud workspaces

`.devenv`, `.direnv`, `.devenv-state`, Bazel outputs, generated output and dependencies
are ignored. `make setup` fetches Bazel's Nix tool repositories. Nix owns immutable npm
and gem environments; deleting local `node_modules` does not clear those caches.
Blog preview setup links its ignored `node_modules` to the same Nix dependency tree.
Setup does not change application lockfiles.

Cloud startup uses the same bootstrap and root `make setup`. A host without
native Nix can use the pinned workspace-local nix-portable launcher described
in the saved environment settings; it only supplies Nix. Activate devenv from the
root and use `make dev` or a project's `make dev` to start servers. Existing cloud
instructions that invoke `devenv tasks run repo:setup` or `devenv up` must use
`make setup` and `make dev` respectively.
