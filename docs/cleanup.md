# Migration cleanup complete

Cleanup was completed on 5 October 2026. The homepage, blog and uses sites are
live on AWS, and merges to `main` deploy through GitHub Actions using OIDC.

## Completed retirement

- Destroyed the example, library, computer, links and travel infrastructure and
  removed the howto DNS record. Both legacy Terraform states are empty, and the
  retired roots and adoption scripts have been removed from this repository.
- Deleted the unused email-validated certificate with a reviewed human apply.
  Updated the kernel's shared role permission to tag the active DNS certificate.
  Automatic deployment remains enabled; CI has no certificate
  deletion permission.
- Removed the primary repository's 15 obsolete AWS/Notion deployment secrets.
  Deleted the remaining `computer.mads-hartmann.com` and `mads-hartmann.com` IAM
  deployment users, their access keys and their policies.
- Backed up and removed seven stale current S3 objects outside Terraform state:
  two from the homepage bucket and five from the blog bucket. Retained
  Terraform-managed content remains present. CloudFront invalidations completed.
- Removed the old Vercel projects, as confirmed by the owner.
- Retired the old Notion integration and removed its saved token from 1Password,
  as confirmed by the owner. Uses is maintained as Markdown in this repository.
- Deprecated and archived
  [mads-hartmann.com-v2](https://github.com/mads-hartmann/mads-hartmann.com-v2) and
  [cloud.mads-hartmann.com](https://github.com/mads-hartmann/cloud.mads-hartmann.com).
  Both repositories point here.

The retired blog object at
`/sre,/reliability/2021/03/14/increment-magazine.html` was removed after its 301
redirect deployed. The literal comma and both `%2C`/`%2c` forms redirect to the
retained `/sre/2021/03/14/increment-magazine.html` post.

## Verification and recovery records

The [merge-triggered deployment for PR #9](https://github.com/mads-hartmann/mads-hartmann.com/actions/runs/37265318664)
passed all four OIDC applies and site checks. The final authenticated cleanup
helper recorded `verified-complete`: both retired IAM users and all seven stale
current objects are absent, retained content is present, and the live sites and
legacy blog redirects pass HTTP checks.

The private report is under `.migration/remaining-cleanup/<run>/report.json`,
with object backups under that run's `objects/` directory and state snapshots
under `states/`. Earlier state snapshots, local plans/backend metadata and legacy
source, including locally modified provider locks, remain under the ignored
`.migration/` directory. Content backups for the five retired buckets were waived
by the owner. No private reports, states, plans or credential data are committed.

The active DNS certificate, its renewal CNAME, the hosted zone and mail records
remain in place. Both backend buckets and their state history are preserved;
personal and unrelated IAM users were outside this cleanup's scope.

Use [deployment](deployment.md) for current operations. The original migration
procedure is in the [historical runbook](archive/migration.md); its retired
commands must not be rerun.
