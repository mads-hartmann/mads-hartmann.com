# Migration runbook

This branch changes source and deployment configuration; it does not apply AWS,
rename the remote branch, change DNS, revoke keys or archive repositories.
The first merge is safe because deployment defaults to disabled. The initial
migration requires human AWS access for inventory, state transfer and the origin
transition, in addition to the small permanently manual kernel.

## 1. Merge with deployment disabled and freeze old writers

Merge after the `Checks` job passes. The workflow checks pull requests and pushes
to `main`. Disable any old scheduled/deploy workflows in
other repositories, and pause automatic Vercel deployments. The cloud repository
is already archived. Do not run the old production Terraform apply.

Authenticate to AWS account `790804032123` as a human and install AWS CLI,
Terraform 1.16.4 or a later 1.16 patch release (1.16.5 recommended), and `gh`.
Authenticate `gh` with repository administration access.
Do not place credentials in tfvars. Run:

```sh
python3 scripts/inventory.py
```

This is read-only against AWS. `.migration/` is ignored and created privately.
It contains the two legacy state snapshots, DNS/certificate/distribution inventory,
non-secret tfvars and import manifests. State snapshots contain old IAM secrets;
keep them private. The helper refuses the wrong account, ambiguous distributions,
or an unexpected www CNAME. Review all manifests against the actual AWS console.
Archive deployed content for travel/library/links/example/computer and howto before
retiring them; some deployed content has no source in these repositories.

Review the bucket regions, ACM DomainName/SAN ordering and validation method, www TTL, OAI and any existing
homepage distribution. Copy the non-secret discovered values into the corresponding
`production.auto.tfvars` (or an additional committed `production.auto.tfvars.json`),
keeping account/region settings. Match `kernel.site_buckets` if bucket names differ.
Do not guess missing IDs or move an existing bucket between regions. Check existing
GitHub OIDC provider/trust customization, and update the kernel subject if needed.

Export the public shared inputs for manual site imports/plans:

```sh
export TF_VAR_zone_id=Z18NSONI21UYAE
export TF_VAR_certificate_arn=arn:aws:acm:us-east-1:790804032123:certificate/344b3275-d3d8-4d12-81d3-eda18bf46967
scripts/build.sh
```

## 2. Adopt and apply the manual kernel

The existing state bucket bootstraps its own remote backend. The kernel key is
new and distinct from both legacy keys. Preview the imports, then execute them:

Check `terraform version` first. Both 1.16.4 and 1.16.5 are validated in CI; all
automatic plans/applies use the pinned 1.16.5 release. If an earlier attempt stopped
at `init` with a version error, no imports ran. Update the checkout and rerun the
helper after correcting the version requirement.

```sh
export GITHUB_TOKEN="$(gh auth token)"
python3 scripts/adopt.py kernel
python3 scripts/adopt.py kernel --execute
terraform -chdir=terraform/kernel plan -out=kernel.tfplan
terraform -chdir=terraform/kernel apply kernel.tfplan
unset GITHUB_TOKEN
```

The import helper skips matching existing addresses, so a partially completed
import can be resumed. Inspect any existing managed bucket policy before replacing
it with the TLS-only policy; preserve unrelated required grants explicitly.
Use `GITHUB_TOKEN` for both imports and the manual plan/apply. The manual apply
keeps `main` as the default branch, manages the existing Production environment,
installs branch rules and OIDC roles, and sets `TERRAFORM_DEPLOY_ENABLED=false`.
Existing inventory manifests from before this change remain usable: the import
helper maps the former default-branch resource address to its current address.
Do not enable deployment until the state transfers below are complete.

If an import attempt stops partway through, rerun the same helper after fixing the
reported error. It reads the current state and skips resources whose IDs already
match the manifest. Keep the state and inventory intact; no reset or targeted apply
is needed. The kernel defines GitHub variable keys from the configured identities
so imports can run before any OIDC roles have been created.

## 3. Adopt shared and blog resources

```sh
python3 scripts/adopt.py shared --var-file .migration/shared.tfvars.json
python3 scripts/adopt.py shared --var-file .migration/shared.tfvars.json --execute
terraform -chdir=terraform/stacks/shared plan -out=shared.tfplan
terraform -chdir=terraform/stacks/shared apply shared.tfplan
export TF_VAR_certificate_arn="$(terraform -chdir=terraform/stacks/shared output -raw certificate_arn)"
python3 scripts/adopt.py blog --var-file .migration/blog.tfvars.json
python3 scripts/adopt.py blog --var-file .migration/blog.tfvars.json --execute
python3 scripts/adopt.py blog --release-legacy
python3 scripts/adopt.py blog --release-legacy --execute
```

The inventory confirmed an issued email-validated wildcard/apex certificate used
by seven distributions. Import it at `aws_acm_certificate.primary` with its existing
domain/SAN ordering and `legacy_certificate_validation_method=EMAIL`; do not change
its validation method. Its replacement/deletion is blocked by `prevent_destroy`.
The committed production values match this inventory. An inventory generated before
the validation-method field was added still works with the default `EMAIL` value.

The shared plan should create `aws_acm_certificate.dns`, one Route 53 validation
CNAME shared by apex/wildcard, and a validation waiter. **Stop if it replaces or
destroys the imported certificate.** Review the plan before applying. Validation
can take several minutes; site stacks receive only the issued DNS certificate's
ARN. Export the new ARN as shown above before planning/applying any site. When
resuming in another shell, repeat that export and the zone-ID export from step 1.
The old certificate remains available through `legacy_certificate_arn` for recovery.
Other DNS records, including mail, are preserved.

Terraform owns the validation CNAME so ACM can renew the DNS certificate
automatically while it is in use. Keep that CNAME after issuance. See
[AWS DNS validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html).

Blog import moves the bucket, access block, bucket policy, CloudFront distribution,
and A/AAAA records to `stacks/blog.tfstate`. The release step verifies each new ID,
saves another private old-state snapshot, then removes exactly those addresses
from legacy state. It leaves legacy deploy IAM users/keys, OAI and Lambda@Edge
resources in the old state for later destruction. No live resource is deleted by
`state rm`. From this point the old configuration must never be applied normally.

Inspect retained bucket ACLs before enabling `BucketOwnerEnforced`. If a bucket
ACL grants anyone other than the bucket owner access, reset it to private with the
human session (`aws s3api put-bucket-acl --bucket BUCKET --acl private`) first.
Existing object ACLs do not need individual changes. This avoids S3 rejecting the
ownership-controls update for an older public bucket.

First apply the new blog root **with the old OAI still selected**:

```sh
terraform -chdir=terraform/stacks/blog plan -var-file="../../../.migration/blog.tfvars.json" -var=use_oac=false -out=adopt.tfplan
terraform -chdir=terraform/stacks/blog apply adopt.tfplan
```

This removes Lambda associations, installs the viewer-request function, tags the
existing distribution, uploads the generated site and grants both OAI and OAC access
while retaining the old origin identity. After it completes, apply with OAC enabled:

```sh
terraform -chdir=terraform/stacks/blog plan -var-file="../../../.migration/blog.tfvars.json" -out=oac.tfplan
terraform -chdir=terraform/stacks/blog apply oac.tfplan
python3 scripts/smoke-test.py blog "https://$(terraform -chdir=terraform/stacks/blog output -raw distribution_domain)"
```

Keep `legacy_oai_arn` in committed config until this deployment passes, then remove
it and apply to remove the old grant. Check feed, dated/category permalinks, images,
audio, book reviews and 404 responses. All 36 migrated v2 URLs are checked against
the generated Jekyll files by CI, including frontmatter date/category exceptions.

## 4. Stage homepage and uses, then cut over DNS

```sh
python3 scripts/adopt.py homepage --execute
python3 scripts/adopt.py uses --execute
terraform -chdir=terraform/stacks/homepage plan -var=publish_dns=false -out=preview.tfplan
terraform -chdir=terraform/stacks/homepage apply preview.tfplan
terraform -chdir=terraform/stacks/uses plan -out=uses.tfplan
terraform -chdir=terraform/stacks/uses apply uses.tfplan
python3 scripts/smoke-test.py homepage "https://$(terraform -chdir=terraform/stacks/homepage output -raw distribution_domain)"
python3 scripts/smoke-test.py uses "https://$(terraform -chdir=terraform/stacks/uses output -raw distribution_domain)"
```

Use the discovered homepage/uses var-files during import and plan if they contain
settings not yet committed. For an imported homepage distribution with an OAI,
use the same two-phase OAI/OAC transition as the blog. A newly created distribution
can use OAC immediately. During the homepage preview, only the existing www CNAME
is managed; apex A/AAAA records are deliberately deferred and remain untouched.

After the preview passes, import existing homepage A/AAAA records immediately
before cutover. Do not run a `publish_dns=false` apply after importing them.

```sh
python3 scripts/adopt.py homepage --include-dns --execute
terraform -chdir=terraform/stacks/homepage plan -out=cutover.tfplan
terraform -chdir=terraform/stacks/homepage apply cutover.tfplan
```

The final default `publish_dns=true` deletes the adopted www Vercel CNAME before
creating CloudFront A/AAAA aliases, and updates any adopted apex A/AAAA records.
The apex redirects to www; both share the same distribution. Verify the public
www/apex, blog and uses hostnames, 36 redirects, `/uses`, blog feed/media redirects,
and tools/photography 410 responses. Keep the DNS snapshot for rollback.

## 5. Enable OIDC deployments and retire legacy infrastructure

Commit any reviewed adoption settings, clear all local import/plan files, and
confirm each retained physical resource belongs to exactly one remote state.
With human AWS/GitHub credentials, apply the kernel with `deploy_enabled=true`:

```sh
export GITHUB_TOKEN="$(gh auth token)"
terraform -chdir=terraform/kernel plan -var=deploy_enabled=true -out=enable.tfplan
terraform -chdir=terraform/kernel apply enable.tfplan
unset GITHUB_TOKEN
gh workflow run sites.yml --ref main -f stack=all
```

Also set `deploy_enabled=true` in the committed kernel config so future manual
applies preserve it. Confirm the first Actions run successfully assumes all four
roles, plans/applies its own state, invalidates caches and passes HTTP checks.
A harmless content PR then confirms automatic apply on merge. A PR cloud plan
should read state and never apply. Inspect CloudTrail session identities if an
AWS API permission needs adjustment; only the human kernel can change policies.

Once AWS is serving successfully, archive/remove untracked stale objects from
retained buckets using the private inventory and source manifest; Terraform only
deletes objects it owns. Back up and empty retired site buckets, then inspect the
legacy destroy plan (human session only):

```sh
terraform -chdir=terraform/aws/production init
terraform -chdir=terraform/aws/production plan -destroy -out=retire.tfplan
terraform -chdir=terraform/aws/production apply retire.tfplan
terraform -chdir=terraform/aws/howto init
terraform -chdir=terraform/aws/howto plan -destroy -out=retire.tfplan
terraform -chdir=terraform/aws/howto apply retire.tfplan
```

**Stop if the destroy plan contains the retained blog bucket, distribution, bucket
policy/access block, A/AAAA records, shared zone/certificate or new site resources.**
The legacy blog IAM/OAI/Lambdas should remain in the destroy plan, along with the
retired example/library/computer/links/travel sites. Lambda@Edge replicas may take
hours to become deletable after detachment; retry retirement after replication
clears. Do not forget state entries merely to silence an AWS deletion failure.
If legacy Lambdas cannot be deleted yet, the obsolete user keys can be revoked in
an earlier human-managed cleanup apply, with the reviewed remaining state retained.

Delete retired DNS not present in those states, including any howto records from
Vercel, after checking the DNS snapshot. Keep mail/NS/SOA/ACM validation records.
After all retained distributions use the new DNS certificate and retired
distributions are deleted, confirm the old certificate's ACM `InUseBy` is empty.
Retire it in a separate reviewed cleanup PR/manual apply that removes its
`prevent_destroy` protection and resource. Do not delete it during the cutover;
the current PR deliberately preserves it.
Revoke any older homepage deployment identity found outside the legacy states and
remove obsolete repository AWS/Notion secrets. Remove Vercel projects only after
AWS DNS and content have been verified. Add a deprecation README to the v2 repo
linking here, disable its integrations, then archive it. The cloud repo already
links here and is archived. Remove the frozen legacy Terraform directories in a
later PR after their states are empty and private backups are retained.
