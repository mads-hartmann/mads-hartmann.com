locals { stack = "homepage" }
module "site" {
  depends_on      = [aws_route53_record.legacy_www]
  use_oac         = var.use_oac
  source          = "../../modules/static-site"
  stack           = local.stack
  bucket_name     = var.bucket_name
  domains         = ["mads-hartmann.com", "www.mads-hartmann.com"]
  zone_id         = var.zone_id
  certificate_arn = var.certificate_arn
  publish_dns     = var.publish_dns
  legacy_oai_arn  = var.legacy_oai_arn
  content_dir     = "${path.root}/../../../.build/homepage"
  routing_file    = "${path.root}/../../../.build/routing/homepage.js"
}
output "distribution_id" { value = module.site.distribution_id }
output "distribution_domain" { value = module.site.distribution_domain }
output "bucket_name" { value = module.site.bucket_name }

resource "aws_route53_record" "legacy_www" {
  count   = var.publish_dns ? 0 : 1
  zone_id = var.zone_id
  name    = "www.mads-hartmann.com"
  type    = "CNAME"
  ttl     = var.legacy_www_ttl
  records = ["cname.vercel-dns.com."]
}
