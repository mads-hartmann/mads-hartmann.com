mock_provider "aws" {
  mock_resource "aws_cloudfront_function" {
    defaults = { arn = "arn:aws:cloudfront::790804032123:function/mads-sites-test" }
  }
}
variables {
  zone_id         = "Z18NSONI21UYAE"
  certificate_arn = "arn:aws:acm:us-east-1:790804032123:certificate/ab1542c8-a6eb-43dd-a1ca-2d624c27efba"
}
run "private_site" {
  command = apply
  assert {
    condition     = module.site.bucket_name == var.bucket_name
    error_message = "The site must use its configured content bucket."
  }
}
