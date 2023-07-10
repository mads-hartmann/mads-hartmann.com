terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.7.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-cloud-mads-hartmann-com"
    key    = "production.tfstate"
    region = "eu-central-1"
  }
}

# By default, I want everything to be in eu-central-1
provider "aws" {
  region = "eu-central-1"
}

# Some resources *have* to be created in us-east-1. For example CloudFront distributions and
# some of the associated resources like WAFs, certificates from ACM, and lambda@edge all have
# to be defined us-east-1
provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}

locals {
  acm_certificate_arn = "arn:aws:acm:us-east-1:790804032123:certificate/344b3275-d3d8-4d12-81d3-eda18bf46967"
  route53_zone_id     = "Z18NSONI21UYAE"
}

module "example-mads-hartmann-com" {
  source              = "../modules/site"
  domain              = "example.mads-hartmann.com"
  acm_certificate_arn = local.acm_certificate_arn
  route53_zone_id     = local.route53_zone_id
  enable_waf          = false

  providers = {
    aws = aws.us-east-1
  }

  # All of the following should render
  #
  # https://example.mads-hartmann.com
  # https://example.mads-hartmann.com/
  # https://example.mads-hartmann.com/subdirectory
  # https://example.mads-hartmann.com/subdirectory/
  # https://example.mads-hartmann.com/subdirectory/index.html
  #
  # The following should return 404
  #
  # https://example.mads-hartmann.com/what
  #
  #
}

module "library-mads-hartmann-com" {
  source              = "../modules/site"
  domain              = "library.mads-hartmann.com"
  acm_certificate_arn = local.acm_certificate_arn
  route53_zone_id     = local.route53_zone_id
  enable_waf          = false

  providers = {
    aws = aws.us-east-1
  }
}

module "computer-mads-hartmann-com" {
  source              = "../modules/site"
  domain              = "computer.mads-hartmann.com"
  acm_certificate_arn = local.acm_certificate_arn
  route53_zone_id     = local.route53_zone_id
  enable_waf          = false

  providers = {
    aws = aws.us-east-1
  }
}

module "links-mads-hartmann-com" {
  source              = "../modules/site"
  domain              = "links.mads-hartmann.com"
  acm_certificate_arn = local.acm_certificate_arn
  route53_zone_id     = local.route53_zone_id
  enable_waf          = false

  providers = {
    aws = aws.us-east-1
  }
}

module "blog-mads-hartmann-com" {
  source              = "../modules/site"
  domain              = "blog.mads-hartmann.com"
  acm_certificate_arn = local.acm_certificate_arn
  route53_zone_id     = local.route53_zone_id
  enable_waf          = false

  providers = {
    aws = aws.us-east-1
  }
}

module "travel-mads-hartmann-com" {
  source              = "../modules/site"
  domain              = "travel.mads-hartmann.com"
  acm_certificate_arn = local.acm_certificate_arn
  route53_zone_id     = local.route53_zone_id
  enable_waf          = false

  providers = {
    aws = aws.us-east-1
  }
}
