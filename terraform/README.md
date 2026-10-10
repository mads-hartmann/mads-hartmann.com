# Terraform

The manual `kernel` owns backend storage, GitHub OIDC/IAM and repository controls.
The independent `stacks/shared`, `stacks/homepage`, `stacks/blog` and `stacks/uses`
roots deploy through GitHub Actions after merges to `main`.

See [deployment](../docs/deployment.md) for state ownership, authentication,
manual kernel updates and recovery. The `static-site` module serves each site
from a private S3 bucket through CloudFront with signed origin requests and
Route 53 aliases.

```sh
cd terraform
devenv shell
devenv tasks run infra:check # builds site artifacts; no cloud credentials needed
```

The environment includes the site build tools because Terraform tests load those
artifacts. Site servers stay off here. See [development setup](../docs/development.md)
for first-time activation and tool updates.

Manual plans/applies use a human AWS session. The kernel also needs `GITHUB_TOKEN`;
Actions obtains short-lived AWS credentials through OIDC.
