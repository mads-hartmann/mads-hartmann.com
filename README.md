# mads-hartmann.com

The source and AWS infrastructure for my three sites:

| Site | Source | Build | LLM guide |
| --- | --- | --- | --- |
| [Homepage](https://www.mads-hartmann.com/) | `sites/mads-hartmann.com/src/index.html` | Site-local Node script → HTML and Markdown | [llms.txt](sites/mads-hartmann.com/llms.txt) |
| [Blog](https://blog.mads-hartmann.com/) | `sites/blog.mads-hartmann.com/src` | Jekyll with jekyll-md | [llms.txt](sites/blog.mads-hartmann.com/llms.txt) |
| [Uses](https://uses.mads-hartmann.com/) | `sites/uses.mads-hartmann.com/index.md` | Site-local Node script → HTML and source Markdown | [llms.txt](sites/uses.mads-hartmann.com/llms.txt) |

All three sites share a static footer from [`sites/shared/footer`](sites/shared/footer/README.md),
using Declarative Shadow DOM for style isolation and requiring no browser JavaScript.

Each site’s own build produces Markdown versions of its HTML pages
and copies each site's tracked `llms.txt` unchanged to the site root. Edit the
guides directly in the site folders linked above. HTML advertises its Markdown alternative; CloudFront
serves that alternative when requested with `Accept: text/markdown`. See the
[deployment guide](docs/deployment.md#markdown-and-agent-discovery) for URLs,
content negotiation, and cache behavior.

Development uses [devenv](https://devenv.sh/) and Nix on macOS (Apple Silicon)
and Linux (x86-64). With Nix installed, install the pinned environment tools:

```sh
./scripts/bootstrap-dev.sh
devenv shell
make check
make dev
```

The single root devenv supplies all tools. Makefiles handle dependency setup,
builds, checks, and servers: use `make` at the root or in a project directory to
see its targets. [Development instructions](docs/development.md) cover direnv,
Makefile commands, ports, tool updates, and cloud setup. CI retains its own installation
steps and checks Terraform 1.16.4 and 1.16.5; development and deployment use 1.16.5.
The Terraform check matrix runs only when `terraform/`, its check script, or CI
workflows change (and on manual runs). PR plans likewise run only for Terraform,
Terraform script, or workflow changes. Site builds and workflow linting always
run, and site-only changes still deploy on `main`.

The **manual kernel** in `terraform/kernel` owns the state bucket, GitHub OIDC
provider, separate plan/apply roles, repository variables, `main` branch rules
and the Production environment. Run it with human AWS and GitHub credentials.
GitHub Actions never applies the kernel or reads its state.

The four independent roots under `terraform/stacks` are `shared`, `homepage`,
`blog` and `uses`. Each has its own S3 state key and OIDC roles. Merging to
`main` builds and checks all sites, applies shared infrastructure first, then
applies the site roots. Content is uploaded by Terraform, followed by CloudFront
invalidation and HTTP checks. Actions authenticates to AWS through GitHub OIDC.

See the [Sites workflow](https://github.com/mads-hartmann/mads-hartmann.com/actions/workflows/sites.yml)
and [deployment guide](docs/deployment.md) for state ownership, manual kernel
updates, deployment controls and recovery.
