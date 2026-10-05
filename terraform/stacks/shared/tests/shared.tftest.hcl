mock_provider "aws" {
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:790804032123:certificate/new-dns-certificate"
      domain_validation_options = [
        { domain_name = "mads-hartmann.com", resource_record_name = "_test.mads-hartmann.com.", resource_record_type = "CNAME", resource_record_value = "_test.acm-validations.aws." },
        { domain_name = "*.mads-hartmann.com", resource_record_name = "_test.mads-hartmann.com.", resource_record_type = "CNAME", resource_record_value = "_test.acm-validations.aws." }
      ]
    }
  }
  mock_resource "aws_acm_certificate_validation" {
    defaults = { certificate_arn = "arn:aws:acm:us-east-1:790804032123:certificate/new-dns-certificate" }
  }
}
run "dns_certificate" {
  command = apply
  assert {
    condition     = length(aws_route53_record.validation) == 1
    error_message = "Apex and wildcard validation use the same record and must have one owner."
  }
  assert {
    condition     = aws_acm_certificate.dns.validation_method == "DNS" && aws_acm_certificate.dns.domain_name == "*.mads-hartmann.com" && aws_acm_certificate.dns.subject_alternative_names == toset(["mads-hartmann.com"])
    error_message = "The active certificate must use DNS validation for the wildcard and apex."
  }
  assert {
    condition     = output.certificate_arn == aws_acm_certificate_validation.dns.certificate_arn && output.certificate_arn == aws_acm_certificate.dns.arn
    error_message = "Site outputs must wait for the active certificate's DNS validation."
  }
}
