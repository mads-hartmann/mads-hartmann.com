# Security policy

Proposed policy — awaiting maintainer approval. This document describes the
security properties reviewers should assess; it does not certify that they are
all implemented. See [the threat model](docs/threat-model.md) for source-backed
architecture, control gaps, and deployment assumptions.

## System and scope

This repository builds and deploys the public homepage, blog, Uses, and Computer
sites for mads-hartmann.com. Scope includes site generators and dependencies,
shared rendering, CloudFront routing, GitHub Actions and build artifacts,
Terraform state and IAM, DNS/TLS/email configuration, traffic logging, developer
tools, and executable examples distributed with the blog.

Production serves public static content from private S3 origins through
CloudFront. The repository does not implement visitor accounts, sessions, a
tenant database, or a repository-hosted public content-submission API. The blog has a conditional
third-party comments embed; assess its browser and privacy effects separately. Reassess this policy if
those features are introduced. The manually applied infrastructure kernel is a
privileged administrative boundary, separate from automated component deploys.

## Threat model and trust boundaries

Review these actors and inputs:

- Internet clients control request paths, headers, and traffic volume.
- Contributors can propose source, workflow, dependency, and filename changes;
  a proposal does not itself confer production authority.
- A compromised dependency or build process may control generated files and
  artifacts without initially holding AWS deployment credentials.
- Compromise of one CI job or component role must be assessed against the
  additional authority it can obtain, including fresh OIDC credentials.
- The maintainer intentionally controls published content and manually reviewed
  kernel changes. Protect that authority from lower-trust inputs; do not assume
  an attacker already has the maintainer's full administrative access.

Raw author-controlled Markdown/HTML is part of the publishing model. Rendering
that trusted content is not by itself evidence of an injection vulnerability.
A finding needs an attacker-controlled path across a meaningful boundary.

## Security invariants

1. Public requests may read intended published content, not credentials, state,
   plans, draft previews, or arbitrary runner files. Origin access remains
   distribution-scoped and encrypted in transit.
2. Artifact promotion must not let lower-privilege build output replace
   privileged deployment inputs or cause credentials/private files to be read
   and published. Verify paths, entry types and bytes at the consuming boundary.
3. Production deployment must use the authorized current main revision and its
   corresponding verified artifact. Untrusted PRs must not acquire deployment
   authority; eligible cloud plans must remain subject to explicit gating.
4. Each apply workload should obtain only its intended component identity.
   Separate role names, job names and state files alone do not establish this.
   CI must not administer IAM, backend security, or kernel state.
5. Component state and resource writes must stay within their intended ownership
   boundaries. A principal must not be able to manufacture an ownership claim
   that grants authority over another component or unrelated resource.
6. DNS, certificate and mail changes must remain constrained to the intended
   domain, record types and responsible stack.
7. Published content hashes and immutable URLs must agree. Publication and
   rollback must preserve legitimate referenced assets; secret removal requires
   explicit origin/cache cleanup and cannot recall browser-cached bytes.
8. Traffic logs must retain the configured data minimization and retention
   limits. Paths and user agents remain untrusted and potentially sensitive.
   Treat ingestion/query cost and access to logs as separate concerns.
9. Developer tools and executable examples must not interpret untrusted names or
   data as commands. Keep local preview content separate from production output.

These are review objectives. Known implementation gaps remain reportable.

## Reportable findings and severity context

Provide the affected revision, attacker starting capability, entry point,
control crossed, reachable impact, prerequisites, and evidence. Distinguish
source-backed reasoning, runtime reproduction, and unverified deployment facts.

Prioritize credential disclosure, unauthorized publication, cross-component
authority, DNS/mail changes, private-state exposure, and meaningful availability
or privacy failures. Severity depends on impact and realistic reachability, not
only a CWE, dependency version, missing header, or wildcard permission. Developer
example execution needs a different reachability assessment from internet-facing
production behavior. A protected-main prerequisite can reduce likelihood without
eliminating a build-to-deployment security boundary.

## Exclusions and accepted risk

No finding-class exclusions or accepted vulnerabilities are proposed here.
Tests, historical examples, dependencies, and development workflows are not
blanket exemptions; explain their actual use and impact.

An intentional action using authority the actor already legitimately holds is
not, by itself, privilege escalation. Unsupported assumptions about visitor
sessions or application databases do not establish a finding in this static
architecture.

Any future risk acceptance must record the specific issue, rationale, owner,
compensating controls and review trigger. Existing comments, tests or documentation
are not evidence of maintainer acceptance.

## Known limitations and maintenance

The threat model records source/configuration gaps and documentation discrepancies.
Neither passing mock tests nor an unmerged remediation PR proves a live control.
Revisit this policy and model when changing credentials, workflow triggers,
artifact transport, IAM, origins, routing, logging, dependencies or input trust.

Review the deployed environment separately after manual kernel changes. Keep
raw state, plans, tokens and exploit material out of public reports.

## Private reporting

Maintainer decision pending: confirm a monitored private reporting channel
before publishing reporting instructions. Do not assume that GitHub private
vulnerability reporting is enabled or that a security email address exists.
No response-time commitment or support-window policy has been established.
