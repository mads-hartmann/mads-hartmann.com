# Development

The same devenv configuration supplies tools, dependency setup, builds, checks,
and servers locally and in cloud workspaces. Supported platforms are Apple
Silicon macOS and x86-64 Linux. CI keeps its independent installation steps.

## First-time setup

Install [Determinate Nix](https://docs.determinate.systems/getting-started/) if
`nix --version` does not work. An existing installation is sufficient. From the
repository root:

```sh
./scripts/bootstrap-dev.sh
devenv shell
```

The bootstrap installs pinned devenv 2.3.1, direnv, and modern Bash into your
standard Nix user profile, following [devenv's installation guide](https://devenv.sh/getting-started/).
It builds the tools before replacing their profile entries, so repeating setup
updates these three tools without adding duplicate entries.
Nix normally puts this profile on `PATH`; there is no activation command to
repeat in each terminal. It does not edit shell startup files or Nix settings.
If your shell does not yet see the tools, open a new terminal after installation.
The first environment activation can take several minutes.

[Ruby](https://devenv.sh/languages/ruby/) 3.3.11 uses devenv's built-in version
selector with its documented `nixpkgs-ruby` input.
[Terraform](https://devenv.sh/languages/terraform/) uses the pinned nixpkgs
package (1.16.5). The optional `nixpkgs-terraform` version catalog does not yet
provide a version satisfying this repository's `>= 1.16.4, < 1.17.0` contract.
Node uses `languages.javascript` with the pinned Node 24 package.
Bundler's version comes from the blog's existing `Gemfile.lock` (4.0.16).

Determinate manages `/etc/nix/nix.conf`; any personal Nix settings belong in
`/etc/nix/nix.custom.conf`. This setup needs no edits to either file. See
[Determinate's development environment guide](https://zero-to-nix.com/concepts/dev-env/)
and [devenv's monorepo guidance](https://devenv.sh/guides/monorepo/).

## Project activation

| Directory | Tools | Build/check task | Default server |
| --- | --- | --- | --- |
| Repository root | All project tools | `repo:check` | All three |
| `sites/mads-hartmann.com` | Node, Python | `homepage:build` | Port 8080 |
| `sites/blog.mads-hartmann.com` | Ruby, Bundler, native gem build tools, Node | `blog:build` | Port 4000 |
| `sites/uses.mads-hartmann.com` | Node, Python | `uses:build` | Port 8081 |
| `terraform` | Terraform, actionlint, all site build tools | `infra:check` | None |

Every environment also provides Bash, Git, curl, Python, jq, gawk, and direnv.
Enter a directory and run `devenv shell`. Blog and Uses dependencies install
automatically using frozen lockfiles. Exiting that shell lets you activate
another project. Use direnv for automatic switching between root and child
environments:

```sh
# Bash: add to ~/.bashrc
eval "$(direnv hook bash)"
# Zsh: use this in ~/.zshrc instead
eval "$(direnv hook zsh)"
```

Run `direnv allow` once in each environment directory after reviewing its
`.envrc`. Then `cd` activates the environment and restores the previous one when
you leave. If you change an `.envrc`, review and allow it again. Avoid nesting
`devenv shell` sessions when using direnv.

## Build, test, and run

From any environment, use its task from the table:

```sh
devenv tasks run blog:build
```

At the root, `devenv tasks run repo:check` installs dependencies, builds all
three sites, checks generated pages and routing, validates and tests Terraform,
and checks workflows with actionlint. `devenv test` runs the same validation.
The infrastructure checks need no AWS or GitHub credentials. Actual plans and
applies use the authentication described in [deployment](deployment.md).

`devenv up` starts the current directory's servers with native HTTP readiness
probes. Devenv's [file watching](https://devenv.sh/processes/#file-watching)
rebuilds and restarts servers when their sources or the shared header change.
Jekyll includes drafts and disables its disk cache so cache writes do not trigger
the source watcher. The production blog build remains separate from
`.build/blog-preview`. Stop foreground servers with Ctrl-C. For background
servers use `devenv up --detach` and `devenv processes down` from the same
environment directory. Do not start root and leaf servers simultaneously on
the same ports.

Set `env.HOMEPAGE_PORT`, `env.BLOG_PORT`, or `env.USES_PORT` in the environment's
ignored `devenv.local.nix` to override ports, for example:

```nix
{ env.BLOG_PORT = "4001"; }
```

For detached servers, `devenv processes wait --timeout 30` waits for the native
readiness probes to pass. Existing repository checks validate generated content.

## Shared configuration and updates

`dev/shared/devenv.yaml` supplies shared pinned inputs for all five environments.
Its JSON syntax is valid YAML and lets the bootstrap read pins directly with
Nix. `/dev/shared` imports are relative to the Git root, as recommended for
[devenv monorepos](https://devenv.sh/guides/monorepo/). Each project's `devenv.nix`
declares its language options, tasks, and processes directly. The root composes
the three site configurations and enables Terraform; the Terraform directory
adds root tasks and disables servers by default.

Each environment has a committed `devenv.lock`, generated by devenv. To update
tools, edit the shared input revisions and language versions, bootstrap again
when activation tools change, then run:

```sh
scripts/lock-dev-env.sh
devenv tasks run repo:check
```

All five lockfiles should resolve the same shared inputs. Review and commit the
resulting locks together. CI version pins remain a separate deliberate change.

For the former Kubernetes utility tools, any project can use
`devenv --profile kubernetes shell`. The common tools cover the former scripting
environment. Historical demo environments, GitPod images/automations, and Dev
Container definitions have been removed.

## Local state and cloud workspaces

`.devenv`, `.direnv`, `.devenv-state`, generated site output, and dependencies
are ignored. Dependency setup uses [devenv tasks](https://devenv.sh/tasks/):
Bundler checks the frozen gem bundle, and `execIfModified` tracks the Uses
manifests and installed dependency directory before running `npm ci`.
Gem caches are shared across environments and include the platform and Ruby
derivation identity. The locked protobuf gem needs a build flag that keeps
format warnings from being fatal; it applies only while compiling that gem.
Delete `.devenv-state` and the Uses `node_modules` directory to reinstall
dependencies. No setup task changes application lockfiles.

Cloud startup uses this same bootstrap and `repo:setup` task. A host without
native Nix can use the pinned workspace-local nix-portable launcher described
in the saved environment settings; it only supplies Nix. All project tools and
tasks still come from this checkout. Install scripts prepare retained tools and
dependencies; startup instructions activate the environment and start servers
for each new task. No separate cloud toolchain is maintained.
