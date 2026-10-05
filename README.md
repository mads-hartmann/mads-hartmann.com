# mads-hartmann.com

The source and AWS infrastructure for my three sites:

| Site | Source | Build |
| --- | --- | --- |
| [Homepage](https://www.mads-hartmann.com/) | `sites/mads-hartmann.com/src/index.html` | Copy one self-contained HTML file |
| [Blog](https://blog.mads-hartmann.com/) | `sites/blog.mads-hartmann.com/src` | Jekyll |
| [Uses](https://uses.mads-hartmann.com/) | `sites/uses.mads-hartmann.com/index.md` | Markdown → HTML with a small Node script |

Install Node 24, Ruby 3.3 with Bundler 4.0.16, and Terraform 1.16.4 or a later
1.16 patch release (1.16.5 recommended). CI checks 1.16.4 and 1.16.5; deployments
use 1.16.5. Then:

```sh
scripts/build.sh
node scripts/check-sites.mjs
scripts/check-terraform.sh
scripts/check-workflows.sh
python3 -m http.server 8080 --directory .build/homepage
```

The **manual kernel** in `terraform/kernel` owns the state bucket, GitHub OIDC
provider, separate plan/apply roles, repository variables, `main` branch rules
and the Production environment. Run it with human AWS and GitHub credentials.
GitHub Actions never applies the kernel or reads its state.

The four independent roots under `terraform/stacks` are `shared`, `homepage`,
`blog` and `uses`. Each has its own S3 state key and OIDC roles. Merging to
`main` builds and checks all sites, applies shared infrastructure first, then
applies the site roots. Content is uploaded by Terraform, followed by CloudFront
invalidation and HTTP checks. No AWS access keys or Vercel deployment are needed.

All three sites are live on AWS, and GitHub Actions deployments are enabled.
Production kernel config sets `deploy_enabled=true`, so future manual applies
preserve that setting. See the [Sites workflow](https://github.com/mads-hartmann/mads-hartmann.com/actions/workflows/sites.yml)
and [deployment details](docs/deployment.md) for daily use. The [historical migration runbook](docs/archive/migration.md)
records adoption and cutover. Legacy site infrastructure has been destroyed;
[cleanup](docs/cleanup.md) describes certificate retirement and the remaining external cleanup.
