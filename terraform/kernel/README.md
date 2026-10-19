# Infrastructure kernel

The kernel manages Terraform state storage, GitHub OIDC/IAM roles and policies,
and GitHub repository controls. It is applied manually using your own AWS
credentials and GitHub token; GitHub Actions validates it but does not apply it.

Check out the branch containing the reviewed kernel change. Apply permission
changes **before merging** any stack changes that depend on them. Run the commands
below from the repository root, using the default Terraform workspace.

## Local tools

Complete the [development setup](../../docs/development.md#first-time-setup),
then enter the root environment:

```sh
devenv shell
```

This supplies Terraform 1.16.5, AWS CLI and GitHub CLI. Run the remaining commands
inside that shell.

## Credentials

Export your individual AWS credentials. No AWS profile or SSO login is needed.
Use credentials with permission to manage the kernel resources and access its
state in account `790804032123`.

```sh
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="eu-central-1"
```

For temporary credentials, also export their matching session token:

```sh
export AWS_SESSION_TOKEN="YOUR_SESSION_TOKEN"
```

For long-lived credentials, leave `AWS_SESSION_TOKEN` unset. Confirm the active
account before planning; this command must print `790804032123`:

```sh
aws sts get-caller-identity --query Account --output text
```

The kernel also manages GitHub settings, so it needs a token with repository
administration permissions. With GitHub CLI already authenticated:

```sh
gh auth status
export GITHUB_TOKEN="$(gh auth token)"
```

## Plan and apply

Initialize the existing S3 backend and create a fresh saved plan:

```sh
terraform -chdir=terraform/kernel init \
  -backend-config=backend.hcl \
  -lockfile=readonly

terraform -chdir=terraform/kernel plan -out=kernel.tfplan
```

The backend uses `terraform-state-cloud-mads-hartmann-com` in `eu-central-1`,
with state key `kernel/terraform.tfstate` and native S3 locking.

Review the plan's resource changes before running the next command. For the email
DNS hardening change, expect one in-place update to
`aws_iam_role_policy.shared_apply` adding the scoped mail DNS permissions, with
no resource creation or destruction. Investigate any additional changes.

Apply exactly the reviewed plan:

```sh
terraform -chdir=terraform/kernel apply kernel.tfplan
```

A saved plan applies without another approval prompt. If you change the kernel
configuration or your credentials expire, create and review a fresh plan before
applying.

After a successful apply, remove the plan and clear the credentials from this shell:

```sh
rm terraform/kernel/kernel.tfplan
unset GITHUB_TOKEN AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

The dependent PR can then merge once its checks pass. GitHub Actions applies the
shared and site stacks using their own roles. For the email migration and
post-deployment checks, see [Email DNS](../../docs/deployment.md#email-dns).
