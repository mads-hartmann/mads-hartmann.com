# Remaining migration cleanup

The homepage, blog and uses sites are live on AWS. Both manual and merge-triggered
OIDC deployments have passed. The example, library, computer, links and travel
stacks and the howto DNS record have been destroyed; both legacy states are empty.
The primary repository's 15 obsolete AWS/Notion deployment secrets were removed.
Content backups for the retired buckets were explicitly waived.

Private state snapshots, local plans/backend metadata and legacy source (including
locally modified provider locks) remain under the ignored `.migration/` directory.
The original procedure is in the [historical runbook](archive/migration.md).
Do not recreate the retired roots or remove state entries to hide deletion errors.

## Retire the unused email certificate before merging this change

The human AWS check confirmed the old certificate's `InUseBy` is empty. The
cleanup removes `aws_acm_certificate.primary` and its legacy output from shared;
the DNS certificate, validation CNAME and hosted zone retain their protections.
The kernel's exact certificate-tagging grant is updated to the active DNS ARN.
CI intentionally has no `acm:DeleteCertificate` permission. Apply the shared
removal manually from this branch before merging so Actions sees no deletion.

```sh
terraform -chdir=terraform/stacks/shared plan -out=retire-certificate.tfplan
terraform -chdir=terraform/stacks/shared apply retire-certificate.tfplan
export GITHUB_TOKEN="$(gh auth token)"
terraform -chdir=terraform/kernel plan -out=cleanup-kernel.tfplan
terraform -chdir=terraform/kernel apply cleanup-kernel.tfplan
unset GITHUB_TOKEN
```

Review both saved plans before applying. The shared plan should delete only
`aws_acm_certificate.primary`; it must preserve the DNS certificate, its renewal
CNAME and the hosted zone. The kernel plan should change only the shared apply
role's certificate-tagging grant from the old ARN to the active DNS ARN, with
`TERRAFORM_DEPLOY_ENABLED=true` and OIDC trust/branch controls unchanged.
Regenerate saved plans whenever their configuration or state changes.

## Finish external cleanup

Inventory retained bucket objects against the current stack states, then review
unmanaged stale keys before deleting them. Terraform owns generated content;
it cannot remove old objects that were never adopted into its state. This cleanup
must not delete tracked content, media or the backend buckets/state history.

Check remaining retired DNS records and any old Vercel validation records before
removing them. Preserve mail, NS/SOA and the active ACM renewal CNAME. Identify any
older homepage deployment IAM key outside the destroyed legacy states and revoke
it after confirming its owner and purpose. Removing GitHub secrets does not revoke
an AWS key or the Notion integration token at its issuer.

Remove the old Vercel projects through the authenticated Vercel account. `mads-hartmann.com-v2` now has a deprecation README and is archived.
`cloud.mads-hartmann.com` is also archived and points here. Preserve private
state snapshots for recovery after removing disposable local migration plans.
