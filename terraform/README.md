# Terraform

The manual `kernel` owns backend storage, GitHub OIDC/IAM and repository controls.
The independent `stacks/shared`, `stacks/homepage`, `stacks/blog` and `stacks/uses`
roots deploy through GitHub Actions after merges to `main`.

See [deployment](../docs/deployment.md) for state ownership, authentication,
manual kernel updates and recovery. See the [cleanup record](../docs/cleanup.md)
for completed retirement and preserved recovery data. The legacy AWS roots have
been destroyed and removed.

```sh
scripts/check-terraform.sh # from the repository root; no cloud credentials needed
```

Manual plans/applies use a human AWS session. The kernel also needs `GITHUB_TOKEN`;
Actions obtains short-lived AWS credentials through OIDC.
