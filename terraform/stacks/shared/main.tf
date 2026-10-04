locals { stack = "shared" }
resource "aws_route53_zone" "primary" {
  name = "mads-hartmann.com"
  lifecycle { prevent_destroy = true }
}
resource "aws_acm_certificate" "primary" {
  # Adopt the certificate currently used by seven distributions without replacing it.
  # Keep this address compatible with the inventory/import manifest.
  domain_name               = var.certificate_domain
  subject_alternative_names = var.certificate_alternative_names
  validation_method         = var.legacy_certificate_validation_method
  lifecycle { prevent_destroy = true }
}
resource "aws_acm_certificate" "dns" {
  domain_name               = "*.mads-hartmann.com"
  subject_alternative_names = ["mads-hartmann.com"]
  validation_method         = "DNS"
  lifecycle { prevent_destroy = true }
}
# Apex and wildcard names share one DNS validation record. Keys are known before apply.
locals {
  validation_domains = toset(["mads-hartmann.com"])
}
resource "aws_route53_record" "validation" {
  for_each = local.validation_domains
  zone_id  = aws_route53_zone.primary.zone_id
  name     = one(distinct([for option in aws_acm_certificate.dns.domain_validation_options : option.resource_record_name if trimprefix(option.domain_name, "*.") == each.key]))
  type     = "CNAME"
  ttl      = 300
  records  = [one(distinct([for option in aws_acm_certificate.dns.domain_validation_options : option.resource_record_value if trimprefix(option.domain_name, "*.") == each.key]))]
}
resource "aws_acm_certificate_validation" "dns" {
  certificate_arn         = aws_acm_certificate.dns.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
output "zone_id" { value = aws_route53_zone.primary.zone_id }
output "certificate_arn" { value = aws_acm_certificate_validation.dns.certificate_arn }
output "legacy_certificate_arn" { value = aws_acm_certificate.primary.arn }
