locals { stack = "homepage" }
module "site" {
  source          = "../../modules/static-site"
  stack           = local.stack
  bucket_name     = var.bucket_name
  domains         = ["mads-hartmann.com", "www.mads-hartmann.com"]
  zone_id         = var.zone_id
  certificate_arn = var.certificate_arn
  content_dir     = "${path.root}/../../../.build/homepage"
  routing_file    = "${path.root}/../../../.build/routing/homepage.js"
}
output "distribution_id" { value = module.site.distribution_id }
output "distribution_domain" { value = module.site.distribution_domain }
output "bucket_name" { value = module.site.bucket_name }
