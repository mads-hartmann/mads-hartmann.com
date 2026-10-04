# Deployment

## Ownership

| Root | State key | Responsibility |
| --- | --- | --- |
| Manual kernel | `kernel/terraform.tfstate` | Backend storage, OIDC, IAM roles/policies, GitHub controls |
| Shared | `stacks/shared.tfstate` | Existing Route 53 zone, existing ACM certificate, validation records |
| Homepage | `stacks/homepage.tfstate` | Homepage S3/CloudFront, apex and www DNS, URL redirects |
| Blog | `stacks/blog.tfstate` | Existing blog S3/CloudFront/DNS, generated posts and assets |
| Uses | `stacks/uses.tfstate` | Uses S3/CloudFront/DNS, generated HTML |

All states use the existing `terraform-state-cloud-mads-hartmann-com` bucket in
`eu-central-1`, with native S3 lock files. Versioning protects previous states.
Only the default Terraform workspace is supported. Site bucket regions are
preserved during adoption; the existing blog is in `us-east-1`.

The kernel uses a human AWS session and a human GitHub token through `GITHUB_TOKEN`.
The provider needs repository administration permissions. Neither credential is
stored in Terraform variables or passed to Actions. Only public configuration
(role ARNs, account ID and an enable flag) is stored as repository variables.

Each root has separate `mads-sites-<stack>-plan` and `mads-sites-<stack>-apply`
roles. Plan gets infrastructure reads, its state read, and its lock-file writes.
Apply gets its own state writes and component resource permissions. Both are
explicitly denied IAM administration, backend administration, kernel state and
legacy state. Sites receive the zone/certificate through workflow outputs, without
reading shared state. They cannot assume other component roles.

Apply trusts GitHub's `Production` environment. The kernel permits that environment
only on `master`, requires pull requests and the `Checks` status, and prevents branch
deletion/force pushes. There is no approval gate after a merge. Plan trusts the
`pull_request` subject; the workflow runs cloud plans only for owner-authored PRs
from this repository. Fork PRs still receive every offline check.

Check the actual GitHub OIDC subject before bootstrap. If immutable repository
IDs or a custom subject template are enabled, set `oidc_subject_prefix` to match
GitHub's emitted subject before applying the kernel. Audience remains
`sts.amazonaws.com`. See [GitHub's AWS OIDC guide](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).

CloudFront distribution updates use the `Stack` tag; existing distributions must
be tagged during the human adoption apply. Function permissions use exact names.
OAC and response-header-policy write APIs need broader CloudFront configuration
permissions because they lack tag-based isolation. Those permissions do not grant
access to IAM, another component's state, or other buckets. This boundary is
explicit rather than claiming complete account isolation for those APIs.

## Automatic apply

`.github/workflows/sites.yml` builds all sites and checks routes, Terraform and
workflows on every PR and merge. No path filters can skip a required check.
On `master`, with `TERRAFORM_DEPLOY_ENABLED=true`, it applies shared then the three
sites using `.github/workflows/apply-stack.yml`. A manual run can choose a site;
shared still runs first to provide the certificate and zone outputs.

Production runs queue without cancellation. Each apply job checks that its commit
is still the current `master`, creates a fresh plan, and applies that saved plan in
the same job with the same built files. If a newer commit arrives before a queued
run starts applying, the old run fails the freshness check; the newer run deploys.
A commit arriving during an apply does not interrupt it. Terraform locking handles
manual/Actions overlap. There is no `-target`, uploaded plan artifact, S3 sync job,
or long-lived AWS secret.

Terraform manages every generated object. Assets are uploaded before HTML;
removed tracked files are deleted by Terraform. Existing untracked objects must
be archived and cleaned during migration. Cache lifetime is 60 seconds, capped
at five minutes; successful deployments invalidate and wait, then smoke-test the
CloudFront hostname. Homepage/uses functions return actual 404/410 responses.
Blog missing objects use the generated 404 page; access errors remain 403.

The homepage has no external styles, fonts, scripts or image requests. Uses has
one pinned Markdown dependency. Markdown is trusted author-controlled source and
can include HTML; it is not an untrusted-input renderer. The blog keeps Jekyll,
posts, book reviews, drafts, media, feed and existing permalink behavior.

## Updating the kernel

```sh
terraform -chdir=terraform/kernel init -backend-config=backend.hcl
terraform -chdir=terraform/kernel plan -out=kernel.tfplan
terraform -chdir=terraform/kernel apply kernel.tfplan
```

Review IAM, trust and GitHub-control changes here manually. A merge that changes
the kernel validates it but does not apply it. When adjusting component permissions,
apply the kernel before merging the component change that needs those permissions.

## Recovery

If an apply fails, rerun the Sites workflow on the current `master`. Terraform
reconciles partial work. Never force-unlock a live run. Content rollback is a Git
revert merged through the same checks; the revert rebuilds and deploys all objects.
During initial cutover, keep the Vercel projects and old DNS snapshot until AWS
checks pass. Restore DNS from that snapshot if needed, then fix the branch before
retrying. Keep private state snapshots for recovery; do not push raw states or plans.

Mock tests and validation confirm configuration/graph behavior, not AWS service
permissions or live adoption. The first authenticated human plan and OIDC run must
confirm those against the actual account. See [Terraform's S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3).
