# Deployment

## Ownership

| Root | State key | Responsibility |
| --- | --- | --- |
| Manual kernel | `kernel/terraform.tfstate` | Backend storage, OIDC, IAM roles/policies, GitHub controls |
| Shared | `stacks/shared.tfstate` | Route 53 zone, DNS certificate/validation CNAME, Fastmail MX/SPF/DKIM and DMARC |
| Homepage | `stacks/homepage.tfstate` | Homepage S3/CloudFront, apex and www DNS, URL redirects |
| Blog | `stacks/blog.tfstate` | Blog S3/CloudFront/DNS, generated posts and assets |
| Uses | `stacks/uses.tfstate` | Uses S3/CloudFront/DNS, generated HTML |
| Computer | `stacks/computer.tfstate` | Computer S3/CloudFront/DNS, macOS baseline |

All states use the `terraform-state-cloud-mads-hartmann-com` bucket in
`eu-central-1`, with native S3 lock files. Versioning protects previous states.
Only the default Terraform workspace is supported. Homepage and uses buckets are
in `eu-central-1`; the blog bucket is in `us-east-1`.

Terraform Core 1.16.5 is the only supported version. Development, CI validation
and automatic cloud plans/applies all use 1.16.5. Provider versions and their
checksums are pinned independently of the Core version.

The kernel uses a human AWS session and a human GitHub token through `GITHUB_TOKEN`.
The provider needs repository administration permissions. Neither credential is
stored in Terraform variables or passed to Actions. Only public configuration
(role ARNs, account ID and an enable flag) is stored as repository variables.

Each root has separate `mads-sites-<stack>-plan` and `mads-sites-<stack>-apply`
roles. Plan gets infrastructure reads, its state read, and its lock-file writes.
Apply gets its own state writes and component resource permissions. Both are
explicitly denied IAM administration, backend administration and kernel state.
State access is limited to the role's own root. Sites receive the zone/certificate
through job outputs, without reading shared state. They cannot assume other
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

`.github/workflows/sites.yml` builds all sites and checks routes and workflows
on every branch push and PR. The Terraform check runs for changes to
`terraform/`, its check script, CI workflows or local actions, and on manual
runs. PR cloud plans run for Terraform, Terraform script, workflow or local
action changes, reusing the checked site artifact in the same workflow. The
required `Checks` job waits for the build, Terraform validation and PR plan.
An eligible plan must succeed before merging; failed, cancelled or unexpectedly
skipped plans fail the gate. Plans remain intentionally skipped for unrelated
changes, untrusted PRs and when cloud deployment is disabled. Branch pushes and
manual runs publish `Branch checks`, so they cannot satisfy the PR's required
`Checks` status. Site-only changes still deploy on `main`.
On `main`, with `TERRAFORM_DEPLOY_ENABLED=true`, it plans shared then the affected
sites using the local `.github/actions/apply-stack` action. Each stack keeps its
own Production job and apply role. Feature
branch builds and PRs never apply infrastructure, invalidate CloudFront or run
deployment smoke tests. Shared always runs first to provide the certificate and
zone outputs. A manual run on `main` can choose a site or all sites and bypasses
source filtering.

`scripts/deployment-changes.py` compares each site's inputs with the preceding
successful automatic production run, rather than the previous commit. The baseline
must have completed shared successfully and either deployed or intentionally skipped
every site. Manual runs and green runs with deployment disabled cannot become the
baseline. If the preceding automatic run failed or is incomplete, the workflow is
being rerun, or history/API access is unavailable, all sites are selected. This also
covers a partial deployment followed by a revert whose net source diff is empty.

Each site's source directory (including dependencies and build configuration),
routing function and Terraform stack select that site. Shared footer files,
Markdown routing, redirects, Terraform modules/shared stack, scripts, workflows
and local action changes select all sites. Unrelated documentation and manual kernel changes do not
select site deployments. Build and required checks still run; site jobs alone are
skipped. Manual runs remain available to reconcile infrastructure drift even when
source files have not changed. On automatic runs, actual changes applied to shared
also select all sites so new certificate/zone outputs propagate without a source edit.

Terraform plans use `-detailed-exitcode`: exit code 2 applies the saved plan, exit
code 0 skips apply and CloudFront invalidation, and errors fail the job. Shared
outputs are published even when nothing changed. Selected site jobs still run
smoke tests and HTTP cache checks on a no-change plan so a failed verification can be retried. Saved
plans are removed on both success and failure.

Newer branch/PR runs cancel unfinished checks. Production runs queue without
cancellation. Each apply job checks that its commit
is still the current `main`, creates a fresh plan, and applies that saved plan in
the same job with the same built files. If a newer commit arrives before a queued
run starts applying, the old run fails the freshness check; the newer run deploys.
A commit arriving during an apply does not interrupt it. Terraform locking handles
manual/Actions overlap. There is no `-target`, uploaded plan artifact, S3 sync job,
or long-lived AWS secret.

Terraform manages mutable objects and coordinates immutable publication. Assets are uploaded before HTML;
removed tracked mutable files are deleted by Terraform. Content-addressed assets
under `/_assets/<sha256>/` are published append-only and retained when they leave
the current build, so already-open/cached HTML keeps working.
Untracked objects require separate review and removal. Successful deployments
invalidate `/*` and wait, then smoke-test the CloudFront hostname and HTTP cache
contract. Homepage/Uses/Computer functions return actual 404/410 responses.
Blog missing objects use the generated 404 page; access errors remain 403.

The homepage has no external styles, fonts, scripts or image requests. Uses and Computer each have
one pinned Markdown dependency. Markdown is trusted author-controlled source and
can include HTML; it is not an untrusted-input renderer. The blog keeps Jekyll,
posts, book reviews, drafts, media, feed and existing permalink behavior.

## Routing

Edit `routing/redirects.json` for Homepage and Blog redirects.
`scripts/build-routing.mjs` embeds them in the CloudFront functions during builds.
The local preview servers do not run these functions; use the
[site checks](development.md#validation) to verify routing locally.

The blog's former `/about`, `/about/` and `/about/index.html` URLs redirect to
`https://www.mads-hartmann.com/` with HTTP 301 responses.
Biography, work history and education live on the homepage.

## Restoring Computer

Before merging the Computer restoration, apply the reviewed manual kernel change
using the process below. It adds the `computer` stack, its bucket-scoped policies,
`mads-sites-computer-plan` / `mads-sites-computer-apply` roles, and the
`AWS_ROLE_COMPUTER_PLAN` / `AWS_ROLE_COMPUTER_APPLY` repository variables. Actions
cannot create these identities itself. The existing wildcard certificate covers
`computer.mads-hartmann.com`. The required PR plan needs the new plan role too.

After that prerequisite, the normal Sites workflow creates the private bucket,
CloudFront distribution and DNS aliases and uploads the current setup guide
in HTML and Markdown. Older version URLs return 404. The former GitHub Pages
and Notion-sync workflows remain retired; edit the setup page in Git.

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
- Computer's `sites/computer.mads-hartmann.com/build.mjs` does the same for its
  current setup page.
- The blog uses the released [jekyll-md](https://github.com/dblock/jekyll-md) gem,
  pinned in its Gemfile/lockfile and enabled in `src/_config.yml`. It converts
  rendered `.site` content, generates Markdown files, and injects discovery links
  during normal Jekyll builds and previews. A Markdown layout adds the canonical
  HTML URL. Jekyll rebuilds refresh the Markdown and remove deleted pages.
  The small `src/_plugins/llms.rb` generator registers the editable guide in the
  blog project folder as a static file so Jekyll publishes it unchanged.

Each site owns an editable, tracked `llms.txt` in its project folder:
`sites/mads-hartmann.com/llms.txt`, `sites/blog.mads-hartmann.com/llms.txt`,
`sites/uses.mads-hartmann.com/llms.txt`, and `sites/computer.mads-hartmann.com/llms.txt`.
The build copies these files unchanged to
the corresponding site's root. Edit those files directly to change the guides;
their contents are not generated. The site checks verify that the
published copies match the tracked files and that their links resolve.

Each generated HTML page has a `rel="alternate" type="text/markdown"` link and
a `rel="describedby"` link to that site's `llms.txt`. The small `llms.txt` guides
link to Markdown entry points and the other sites; the blog's Markdown archive
links directly to the Markdown for every published post. The shared footer also
has a visible **For agents** link for readers that don't expose metadata.
The blog resolves links and image URLs against each canonical page and rewrites
links to published blog pages to their Markdown alternatives. Fragment links keep
their canonical HTML targets; footnotes use native Markdown references and
definitions. Recording links remain available in the article text. Home strips
inline image bytes while retaining alt text, and Uses publishes its source,
including its explicitly maintained content update date.

All four domains serve `robots.txt` and a canonical-HTML sitemap at `sitemap.xml`.
Home, Uses and Computer copy their small tracked files during their builds, and their
viewer-request functions allow both paths without Markdown negotiation. The blog
continues to use Jekyll's generated crawler files. Sitemap entries omit a synthetic
deployment-time `lastmod` on the single-page sites.

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

## Email DNS

The shared stack owns email DNS in `email.tf`. Fastmail is the only authorized
sender: the apex SPF record ends in `-all`, and DMARC requests rejection of
messages that fail both aligned SPF and aligned DKIM, including on subdomains
(`p=reject; sp=reject`). The two Fastmail MX hosts retain their existing priorities.
Keep all three `fm1`, `fm2` and `fm3` DKIM CNAMEs: Fastmail manages the target keys
and may intentionally leave rotation slots empty.

This deliberately tightens [Fastmail's documented compatibility defaults](https://www.fastmail.help/hc/en-us/articles/1500000280261-Setting-up-your-domain-MX-only),
which use SPF `?all` and DMARC `p=none`. Fastmail [explains](https://www.fastmail.com/blog/email-authentication/)
that neutral SPF accommodates other sending systems. Our `-all` policy instead
requires every legitimate sending service to be authorized in SPF. DMARC
enforcement is a separate choice: `p=reject` requires an aligned SPF or DKIM pass
and can work even with neutral SPF. The strict policy here is intentional;
account for any new sender before enabling it.

The initial adoption uses `imports.tf` to import the existing MX, apex TXT and
three DKIM CNAME record sets. DMARC is new. Imports run with the normal shared
plan/apply and are skipped once the records are in state; no overwrite flag or
manual state editing is needed. The apex TXT resource owns the entire TXT record
set, so preserve any additional verification values if adding them later.

Roll out in this order:

1. Apply the kernel using the authenticated human session described above **before
   merging**. The added shared-role permissions allow only apex MX, apex/DMARC TXT
   and the three named DKIM CNAMEs in this hosted zone. Site roles remain limited
   to A/AAAA aliases; existing ACM validation permissions are retained.
2. Check that all legitimate senders use Fastmail or have their own aligned DKIM
   configuration, and confirm a recent outgoing Fastmail message has passing,
   aligned authentication. Other sending services must be accounted for before
   enforcement. No DMARC report mailbox is assumed or provisioned by Terraform.
3. Review a fresh shared plan: on first adoption expect **five imports, one SPF
   update and one DMARC creation**, with no MX/DKIM changes or deletions. A different
   result requires checking live DNS/state before applying. In particular, do not
   remove unrelated apex TXT values. Merge to deploy through the existing shared
   workflow, or apply the reviewed shared plan using a human AWS session.
4. After DNS propagation, check the apex SPF and `_dmarc` TXT records, both MX hosts,
   and all three DKIM CNAMEs. Send a message to an independent receiving service
   and inspect its `Authentication-Results` header for aligned `dkim=pass` and
   `dmarc=pass`. DNS configuration alone cannot verify actual outgoing signing.

## Recovery

If an apply fails, rerun the Sites workflow on the current `main`. Terraform
reconciles partial work. Never force-unlock a live run. Content rollback is a Git
revert merged through the same checks; the revert rebuilds and deploys all objects.
State bucket versioning retains previous states. Keep any local snapshots private;
do not push raw states or plans.

Mock tests and validation check configuration and dependency graphs. Authenticated
plans and applies check AWS service permissions against the account. See
[Terraform's S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3).

## HTTP caching and asset versions

| Representation | Browser | CloudFront |
| --- | --- | --- |
| HTML, Markdown, feeds, discovery files and original asset URLs | `max-age=0,must-revalidate` | `s-maxage=3600` |
| `/_assets/<sha256>/...` | `max-age=31536000,immutable` | Up to one year |

The build's final `scripts/fingerprint-assets.mjs` pass creates SHA-256-addressed
copies of static assets and rewrites HTML URLs (including `srcset`, posters,
inline CSS, and stylesheet/script links). CSS dependencies are rewritten before
the stylesheet is hashed: changing a font or background image also changes its
parent stylesheet URL. Circular stylesheet dependencies fail the build. Existing
original URLs remain available for Markdown, feeds and external links with the
mutable policy. Current JavaScript is self-contained; if module imports or
runtime asset loading are introduced, integrate their dependency graph into this
step or use a bundler before enabling immutable URLs for those dependencies.

HTML deliberately revalidates on each navigation instead of keeping the previous
60-second browser TTL. That costs a conditional network round trip for the small
document, but makes deployment invalidation effective immediately for new
navigations; browsers cannot be invalidated by CloudFront. Reused assets need no
network requests for a year. The edge retains mutable objects for one hour
between deployments, bounding stale content if deployment or invalidation fails.
The existing full invalidation clears canonical and
rewritten HTML/Markdown paths, mutable aliases and any previously uncompressed
cached responses. It does not evict browser caches or delete retained S3 assets.

The AWS-managed `CachingOptimized` policy enables normalized `Accept-Encoding`
cache keys and both Brotli and gzip; legacy `forwarded_values` cannot enable
Brotli. It excludes cookies and query strings. HTML/Markdown negotiation remains
safe because the viewer-request function rewrites the URI before cache lookup.
This policy has a one-second minimum and a one-year maximum TTL; the minimum is
acceptable for this entirely public static content, but do not reuse it for
private or `no-store` responses. Using its published ID avoids creating a new
policy or requiring kernel IAM changes. `compress=true` permits edge compression
for eligible types and sizes; AWS can skip compression under load, so deployment
checks report the actual encoding instead of treating an occasional identity
response as a configuration failure.

S3 already supplies `ETag` and `Last-Modified`; do not synthesize or override them.
CloudFront forwards conditional revalidation and can return bodyless `304`
responses to `If-None-Match` / `If-Modified-Since`. Compression changes a strong
S3 ETag to a weak ETag (`W/`) when appropriate, which remains valid for cache
revalidation. Terraform `source_hash` is a deployment change detector, not the
HTTP ETag. The post-deploy check exercises identity/gzip/Brotli requests,
matching ETags, date validators, and the precedence of `If-None-Match` over dates.
Those live assertions run only after deployment; offline tests cannot prove AWS
edge behavior.

Old fingerprinted objects are intentionally retained indefinitely, including
across rollbacks. A single `terraform_data.immutable_assets` resource triggers
`scripts/upload-immutable-assets.py` whenever the full asset manifest or publisher
changes. The publisher validates every content hash before writing, uses explicit
MIME types (including WebP, AVIF and WOFF2), and uploads with the immutable policy.
It requires Python 3 and the AWS CLI, already installed in Actions and the devenv
shell. Bucket ownership and access policy precede it; HTML depends on successful
publication. Failed uploads fail the apply; retries safely write identical bytes.
There is no destroy provisioner and no asset deletion command. Individual
immutable objects are deliberately outside Terraform object ownership; mutable
objects stay under `aws_s3_object`. Site Terraform tests use mocked plans (never apply) so the publisher
never runs. Separate unit tests exercise upload arguments and failure handling. If retained objects are deleted outside this workflow,
repair the current release with `terraform apply -replace=module.site.terraform_data.immutable_assets`
using the normal reviewed plan workflow. Reintroducing a prior fingerprint writes
identical bytes to its key.
This trades modest storage growth for valid old references. Do not add a simple
age-based lifecycle rule: an old object may still be referenced by current HTML.
Future garbage collection must identify references from retained releases and
respect the one-year cache promise. Sensitive-content removal requires explicit
S3 deletion and CDN invalidation; no infrastructure operation can recall bytes
already cached in a browser.

Primary references checked for this strategy:

- [AWS managed cache policies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html)
- [CloudFront compression and ETag conversion](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/ServingCompressedFiles.html)
- [S3 origin conditional requests](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/RequestAndResponseBehaviorS3Origin.html)
- [HTTP caching, RFC 9111](https://www.rfc-editor.org/rfc/rfc9111.html)
- [Immutable caching, RFC 8246](https://www.rfc-editor.org/rfc/rfc8246.html)
