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

Site apply roles can delete object versions only in their own content bucket.
Terraform's S3 object resource deletes versions, including the null version in
unversioned buckets, so removing a generated page needs `s3:DeleteObjectVersion`
as well as `s3:DeleteObject`. See [S3 deletion permissions](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-with-s3-policy-actions.html).

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

## Markdown and agent discovery

Each site owns Markdown generation in its build tool. The root `scripts/build.sh`
installs site-local dependencies and invokes those builds:

- Home's `sites/mads-hartmann.com/build.mjs` inserts the shared footer, extracts
  Markdown from the main content, adds discovery links, and copies `llms.txt`.
  Its Node dependencies are pinned in that site's `package-lock.json`.
- Uses' `sites/uses.mads-hartmann.com/build.mjs` renders HTML and publishes its
  existing Markdown source, adding the canonical URL and copying `llms.txt`.
- The blog uses the released [jekyll-md](https://github.com/dblock/jekyll-md) gem,
  pinned in its Gemfile/lockfile and enabled in `src/_config.yml`. It converts
  rendered `.site` content, generates Markdown files, and injects discovery links
  during normal Jekyll builds and previews. A Markdown layout adds the canonical
  HTML URL. Jekyll rebuilds refresh the Markdown and remove deleted pages.
  The small `src/_plugins/llms.rb` generator registers the editable guide in the
  blog project folder as a static file so Jekyll publishes it unchanged.

Each site owns an editable, tracked `llms.txt` in its project folder:
`sites/mads-hartmann.com/llms.txt`, `sites/blog.mads-hartmann.com/llms.txt`, and
`sites/uses.mads-hartmann.com/llms.txt`. The build copies these files unchanged to
the corresponding site's root. Edit those files directly to change the guides;
their contents are not generated. The site checks verify that the
published copies match the tracked files and that their links resolve.

Each generated HTML page has a `rel="alternate" type="text/markdown"` link and
a `rel="describedby"` link to that site's `llms.txt`. The small `llms.txt` guides
link to Markdown entry points and the other sites; the blog's Markdown archive
links to every published post. The blog's Markdown keeps the source links and
image URLs, including relative URLs; linked HTML pages advertise their Markdown
alternatives. Recording links remain available in the article text. Home strips
inline image bytes while retaining alt text, and Uses publishes its source.

| HTML URL | Markdown URL |
| --- | --- |
| `/` or `/index.html` | `/index.md` |
| `/series/observability/` | `/series/observability.md` |
| `/2026/01/27/using-ai-to-do-your-best-work.html` | `/2026/01/27/using-ai-to-do-your-best-work.md` |

The blog follows jekyll-md’s convention for directory pages: `/talks/` and
`/talks/index.html` both negotiate to `/talks.md`. The root uses `/index.md`.

Direct `.md` URLs work with any `Accept` header. The shared CloudFront
viewer-request code also rewrites an HTML request to its Markdown object when
`Accept` explicitly includes `text/markdown` with a nonzero quality at least as
high as HTML. Missing headers, wildcards alone, an HTML preference, and
`text/markdown;q=0` keep HTML. Existing redirects run before negotiation; feeds
and assets are never converted.

The URI rewrite happens before CloudFront's cache lookup, keeping HTML and
Markdown in distinct cache entries without forwarding `Accept` to S3. The
response headers policy adds `Vary: Accept, Accept-Encoding` for downstream
caches and `Link: </llms.txt>; rel="describedby"; type="text/plain"` for discovery
from Markdown responses too. S3 serves `.md` as `text/markdown; charset=utf-8`
and `llms.txt` as `text/plain; charset=utf-8`. These changes use the existing
site stacks, functions, policies, and private buckets; no kernel/IAM change is
needed.

Build and check locally with `make check` inside the root devenv shell. The plain local
static servers expose the generated files but do not emulate CloudFront's
negotiation or headers. The blog preview also publishes Markdown for drafts. Routing
tests run the generated functions in a JavaScript VM, and deployment smoke tests
verify the live headers, explicit URLs, and alternating HTML/Markdown requests:

```sh
curl -i https://www.mads-hartmann.com/ -H 'Accept: text/markdown'
curl -i https://blog.mads-hartmann.com/index.md
curl -i https://uses.mads-hartmann.com/llms.txt
```

## Recovery

If an apply fails, rerun the Sites workflow on the current `main`. Terraform
reconciles partial work. Never force-unlock a live run. Content rollback is a Git
revert merged through the same checks; the revert rebuilds and deploys all objects.
State bucket versioning retains previous states. Keep any local snapshots private;
do not push raw states or plans.

Mock tests and validation check configuration and dependency graphs. Authenticated
plans and applies check AWS service permissions against the account. See
[Terraform's S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3).
