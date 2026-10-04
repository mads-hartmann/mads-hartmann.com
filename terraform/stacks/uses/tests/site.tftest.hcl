mock_provider "aws" {
  mock_resource "aws_cloudfront_function" {
    defaults = { arn = "arn:aws:cloudfront::790804032123:function/mads-sites-test" }
  }
}
variables {
  zone_id         = "Z18NSONI21UYAE"
  certificate_arn = "arn:aws:acm:us-east-1:790804032123:certificate/344b3275-d3d8-4d12-81d3-eda18bf46967"
}
run "private_site" {
  command = apply
  assert {
    condition     = module.site.bucket_name == var.bucket_name
    error_message = "Adoption must preserve the physical bucket."
  }
}
