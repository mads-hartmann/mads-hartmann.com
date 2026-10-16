# mads-hartmann.com

The source and AWS infrastructure for my four sites:

| Site | Instructions | Build |
| --- | --- | --- |
| [Homepage](https://www.mads-hartmann.com/) | [Homepage README](sites/mads-hartmann.com/README.md) | Node: HTML and Markdown |
| [Blog](https://blog.mads-hartmann.com/) | [Blog README](sites/blog.mads-hartmann.com/README.md) | Jekyll with jekyll-md |
| [Uses](https://uses.mads-hartmann.com/) | [Uses README](sites/uses.mads-hartmann.com/README.md) | Node: HTML and source Markdown |
| [Computer](https://computer.mads-hartmann.com/) | [Computer README](sites/computer.mads-hartmann.com/README.md) | Node: macOS baseline and historical archives |

All four sites use the [shared footer](sites/shared/footer/README.md).
The [Terraform README](terraform/README.md) covers infrastructure work.
Each site also publishes Markdown pages and its own editable `llms.txt`; see
[Markdown and agent discovery](docs/deployment.md#markdown-and-agent-discovery).

## Local development

Development uses [devenv](https://devenv.sh/) and Nix on macOS (Apple Silicon)
and Linux (x86-64). With Nix installed, run from the repository root:

```sh
./scripts/bootstrap-dev.sh
devenv shell
make check
make dev
```

The root devenv supplies all tools. Makefiles handle dependency setup, builds,
checks and servers. Run `make` at the root or in a project directory to see its
targets. See [Development](docs/development.md) for first-time setup, ports,
validation, tool updates and cloud workspaces.

## Deployment

Merging to `main` builds and checks all sites, then deploys them to AWS with
Terraform when deployment is enabled. The infrastructure kernel is applied manually.

See the [Sites workflow](https://github.com/mads-hartmann/mads-hartmann.com/actions/workflows/sites.yml)
and [Deployment](docs/deployment.md) for CI checks, state ownership, manual kernel
updates, deployment controls and recovery.
