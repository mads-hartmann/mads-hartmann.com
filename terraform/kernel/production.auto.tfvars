# Adoption and DNS cutover are complete. Apply the kernel manually to enable CI.
account_id        = "790804032123"
region            = "eu-central-1"
github_owner      = "mads-hartmann"
github_repository = "mads-hartmann.com"
deploy_enabled    = true
state_bucket      = "terraform-state-cloud-mads-hartmann-com"
zone_id           = "Z18NSONI21UYAE"
certificate_arn   = "arn:aws:acm:us-east-1:790804032123:certificate/344b3275-d3d8-4d12-81d3-eda18bf46967"
site_buckets = {
  homepage = "mads-hartmann.com"
  blog     = "blog.mads-hartmann.com"
  uses     = "uses.mads-hartmann.com"
}
