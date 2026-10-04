locals { stack = "blog" }
module "site" {
  use_oac         = var.use_oac
  source          = "../../modules/static-site"
  stack           = local.stack
  bucket_name     = var.bucket_name
  domains         = ["blog.mads-hartmann.com"]
  zone_id         = var.zone_id
  certificate_arn = var.certificate_arn
  publish_dns     = var.publish_dns
  legacy_oai_arn  = var.legacy_oai_arn
  content_dir     = "${path.root}/../../../.build/blog"
  routing_file    = "${path.root}/../../../.build/routing/blog.js"
}
output "distribution_id" { value = module.site.distribution_id }
output "distribution_domain" { value = module.site.distribution_domain }
output "bucket_name" { value = module.site.bucket_name }
