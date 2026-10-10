# mads-hartmann.com

The source and AWS infrastructure for my three sites:

| Site | Source | Build |
| --- | --- | --- |
| [Homepage](https://www.mads-hartmann.com/) | `sites/mads-hartmann.com/src/index.html` | Insert shared header into one self-contained HTML file |
| [Blog](https://blog.mads-hartmann.com/) | `sites/blog.mads-hartmann.com/src` | Jekyll |
| [Uses](https://uses.mads-hartmann.com/) | `sites/uses.mads-hartmann.com/index.md` | Markdown → HTML with a small Node script |

All three sites share a static header from [`sites/shared/header`](sites/shared/header/README.md),
using Declarative Shadow DOM for style isolation and requiring no browser JavaScript.

Development uses [devenv](https://devenv.sh/) and Nix on macOS (Apple Silicon)
and Linux (x86-64). With Nix installed, install the pinned environment tools:

```sh
./scripts/bootstrap-dev.sh
devenv shell
devenv tasks run repo:check
devenv up
```

Run these from the root for all tools and sites, or enter a project directory
and use `devenv shell` and `devenv up` there. Dependencies install automatically
on activation. [Development instructions](docs/development.md) cover direnv,
project tasks, ports, tool updates, and cloud setup. CI retains its own installation
steps and checks Terraform 1.16.4 and 1.16.5; development and deployment use 1.16.5.

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
