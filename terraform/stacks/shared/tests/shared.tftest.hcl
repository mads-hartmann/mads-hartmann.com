mock_provider "aws" {
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:790804032123:certificate/344b3275-d3d8-4d12-81d3-eda18bf46967"
      domain_validation_options = [
        { domain_name = "mads-hartmann.com", resource_record_name = "_test.mads-hartmann.com.", resource_record_type = "CNAME", resource_record_value = "_test.acm-validations.aws." },
        { domain_name = "*.mads-hartmann.com", resource_record_name = "_test.mads-hartmann.com.", resource_record_type = "CNAME", resource_record_value = "_test.acm-validations.aws." }
      ]
    }
  }
}
run "deduplicate_validation" {
  command = apply
  assert {
    condition     = length(aws_route53_record.validation) == 1
    error_message = "Apex and wildcard validation use the same record and must have one owner."
  }
}
