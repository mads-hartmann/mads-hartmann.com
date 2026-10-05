account_id        = "790804032123"
region            = "eu-central-1"
github_owner      = "mads-hartmann"
github_repository = "mads-hartmann.com"
deploy_enabled    = true
state_bucket      = "terraform-state-cloud-mads-hartmann-com"
zone_id           = "Z18NSONI21UYAE"
certificate_arn   = "arn:aws:acm:us-east-1:790804032123:certificate/ab1542c8-a6eb-43dd-a1ca-2d624c27efba"
site_buckets = {
  homepage = "mads-hartmann.com"
  blog     = "blog.mads-hartmann.com"
  uses     = "uses.mads-hartmann.com"
}
