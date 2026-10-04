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
override_resource {
  target = aws_acm_certificate.primary
  values = {
    arn                       = "arn:aws:acm:us-east-1:790804032123:certificate/344b3275-d3d8-4d12-81d3-eda18bf46967"
    domain_validation_options = []
  }
}
run "migrate_email_to_dns" {
  command = apply
  assert {
    condition     = length(aws_route53_record.validation) == 1
    error_message = "Apex and wildcard validation use the same record and must have one owner."
  }
  assert {
    condition     = aws_acm_certificate.primary.validation_method == "EMAIL" && aws_acm_certificate.primary.domain_name == "*.mads-hartmann.com" && aws_acm_certificate.primary.subject_alternative_names == toset(["mads-hartmann.com"])
    error_message = "Adoption must preserve the existing email certificate's immutable inputs."
  }
  assert {
    condition     = aws_acm_certificate.dns.validation_method == "DNS" && aws_acm_certificate.dns.arn != aws_acm_certificate.primary.arn
    error_message = "DNS validation must use a separate certificate without replacing the live one."
  }
  assert {
    condition     = output.certificate_arn == aws_acm_certificate_validation.dns.certificate_arn && output.certificate_arn == aws_acm_certificate.dns.arn && output.legacy_certificate_arn == aws_acm_certificate.primary.arn
    error_message = "Site outputs must wait for the new certificate's validation and retain the old ARN for recovery."
  }
}
