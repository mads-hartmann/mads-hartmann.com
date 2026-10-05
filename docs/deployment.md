# Deployment

## Ownership

| Root | State key | Responsibility |
| --- | --- | --- |
| Manual kernel | `kernel/terraform.tfstate` | Backend storage, OIDC, IAM roles/policies, GitHub controls |
| Shared | `stacks/shared.tfstate` | Route 53 zone, DNS certificate and validation CNAME |
| Homepage | `stacks/homepage.tfstate` | Homepage S3/CloudFront, apex and www DNS, URL redirects |
| Blog | `stacks/blog.tfstate` | Blog S3/CloudFront/DNS, generated posts and assets |
| Uses | `stacks/uses.tfstate` | Uses S3/CloudFront/DNS, generated HTML |

All states use the `terraform-state-cloud-mads-hartmann-com` bucket in
`eu-central-1`, with native S3 lock files. Versioning protects previous states.
Only the default Terraform workspace is supported. Homepage and uses buckets are
in `eu-central-1`; the blog bucket is in `us-east-1`.

Terraform Core supports `>= 1.16.4, < 1.17.0`. CI validates both 1.16.4 and 1.16.5;
automatic cloud plans/applies use 1.16.5. Provider versions and their checksums
are pinned independently of the Core version range.

The kernel uses a human AWS session and a human GitHub token through `GITHUB_TOKEN`.
The provider needs repository administration permissions. Neither credential is
stored in Terraform variables or passed to Actions. Only public configuration
(role ARNs, account ID and an enable flag) is stored as repository variables.

Each root has separate `mads-sites-<stack>-plan` and `mads-sites-<stack>-apply`
roles. Plan gets infrastructure reads, its state read, and its lock-file writes.
Apply gets its own state writes and component resource permissions. Both are
explicitly denied IAM administration, backend administration and kernel state.
State access is limited to the role's own root. Sites receive the zone/certificate
through workflow outputs, without reading shared state. They cannot assume other
component roles.

Apply trusts GitHub's `Production` environment. The kernel permits that environment
only on `main`, requires pull requests and the `Checks` status, and prevents branch
deletion/force pushes. There is no approval gate after a merge. Plan trusts the
`pull_request` subject; the workflow runs cloud plans only for owner-authored PRs
from this repository. Fork PRs still receive every offline check.

The OIDC subject must match the workflow's GitHub identity. If immutable repository
IDs or a custom subject template are enabled, set `oidc_subject_prefix` to match
GitHub's emitted subject before applying the kernel. The audience is
`sts.amazonaws.com`. See [GitHub's AWS OIDC guide](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).

CloudFront distribution updates are restricted by the site's `Stack` tag.
The site module tags its distribution and function. Distribution and function
creation require `Resource = "*"` with the site's requested `Stack` tag. Separate
`TagResource` permissions authorize those initial tags without allowing a site to
retag another stack's resources. Function updates and tagging use exact names and
the existing `Stack` tag. See [CloudFront's IAM action reference](https://docs.aws.amazon.com/service-authorization/latest/reference/list_cloudfront.html)
and the [distribution creation API's required IAM actions](https://docs.aws.amazon.com/cloudfront/latest/APIReference/API_CreateDistributionWithTags.html).
OAC and response-header-policy write APIs need broader CloudFront configuration
permissions because they lack tag-based isolation. Those permissions do not grant
access to IAM, another component's state, or other buckets. This boundary is
explicit rather than claiming complete account isolation for those APIs.

## Automatic apply

`.github/workflows/sites.yml` builds all sites and checks routes, Terraform and
workflows on every PR and merge. No path filters can skip a required check.
On `main`, with `TERRAFORM_DEPLOY_ENABLED=true`, it applies shared then the three
sites using `.github/workflows/apply-stack.yml`. A manual run can choose a site;
shared still runs first to provide the certificate and zone outputs.

Production runs queue without cancellation. Each apply job checks that its commit
is still the current `main`, creates a fresh plan, and applies that saved plan in
the same job with the same built files. If a newer commit arrives before a queued
run starts applying, the old run fails the freshness check; the newer run deploys.
A commit arriving during an apply does not interrupt it. Terraform locking handles
manual/Actions overlap. There is no `-target`, uploaded plan artifact, S3 sync job,
or long-lived AWS secret.

Terraform manages every generated object. Assets are uploaded before HTML;
removed tracked files are deleted by Terraform. Untracked objects require separate
review and removal. Cache lifetime is 60 seconds, capped at five minutes;
successful deployments invalidate and wait, then smoke-test the
CloudFront hostname. Homepage/uses functions return actual 404/410 responses.
Blog missing objects use the generated 404 page; access errors remain 403.

The homepage has no external styles, fonts, scripts or image requests. Uses has
one pinned Markdown dependency. Markdown is trusted author-controlled source and
can include HTML; it is not an untrusted-input renderer. The blog keeps Jekyll,
posts, book reviews, drafts, media, feed and existing permalink behavior.

## Updating the kernel

Shared CI can request only DNS-validated certificates for `mads-hartmann.com` and
`*.mads-hartmann.com` in `us-east-1`, with the shared-stack/project tags. Its ACM
tag permissions cover the existing certificate and shared-tagged certificates;
creation also needs permission to add the initial shared/project tags. ACM
certificate deletion is intentionally excluded. The shared output waits for DNS
validation before downstream stacks can switch their CloudFront viewer certificate.
Keep the validation CNAME for automatic renewal. ACM certificate deletion is a
human operation: apply a reviewed removal plan before merging it so Actions
never needs certificate deletion permissions.

```sh
export GITHUB_TOKEN="$(gh auth token)"
terraform -chdir=terraform/kernel init -backend-config=backend.hcl
terraform -chdir=terraform/kernel plan -out=kernel.tfplan
terraform -chdir=terraform/kernel apply kernel.tfplan
unset GITHUB_TOKEN
```

Review IAM, trust and GitHub-control changes here manually. A merge that changes
the kernel validates it but does not apply it. When adjusting component permissions,
apply the kernel before merging the component change that needs those permissions.
Regenerate a saved plan after changing the kernel; applying an earlier plan uses
the old configuration and policies stored in that plan.

To pause cloud plans and applies, set `deploy_enabled=false` in the kernel's
production configuration and apply the kernel manually. Set it back to `true`
and apply again to resume. Offline PR checks run while deployment is paused.

## Recovery

If an apply fails, rerun the Sites workflow on the current `main`. Terraform
reconciles partial work. Never force-unlock a live run. Content rollback is a Git
revert merged through the same checks; the revert rebuilds and deploys all objects.
State bucket versioning retains previous states. Keep any local snapshots private;
do not push raw states or plans.

Mock tests and validation check configuration and dependency graphs. Authenticated
plans and applies check AWS service permissions against the account. See
[Terraform's S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3).
