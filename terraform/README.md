# Terraform

The manual `kernel` owns backend storage, GitHub OIDC/IAM and repository controls.
The independent `stacks/shared`, `stacks/homepage`, `stacks/blog`, `stacks/uses` and `stacks/computer`
roots deploy through GitHub Actions after merges to `main`.

See [deployment](../docs/deployment.md) for state ownership, authentication,
manual kernel updates and recovery. The `static-site` module serves each site
from a private S3 bucket through CloudFront with signed origin requests and
Route 53 aliases.

The shared stack also owns the `mads-sites-traffic` CloudWatch dashboard. Each
site delivers CloudFront access logs for traffic, user-agent and popular-page
breakdowns. See [traffic analytics](../docs/traffic-analytics.md) for deployment,
costs, retention and how to interpret the charts.

## Format and check

Complete [first-time setup](../docs/development.md#first-time-setup), then run
from the repository root:

```sh
devenv shell
cd terraform
make fmt   # format Terraform
make lint  # check formatting
make check # builds site artifacts, validates and tests; no cloud credentials needed
```

The root environment includes the site build tools because Terraform tests load
those artifacts. See [development setup](../docs/development.md)
for first-time activation and tool updates.

## Plan and deploy

Follow the [kernel README](kernel/README.md) to apply the kernel locally using
individual AWS credential environment variables and a GitHub token.
See [Deployment](../docs/deployment.md) for stack procedures and rollout order.
Actions obtains short-lived AWS credentials through OIDC.
