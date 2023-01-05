terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.48.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-mads-hartmann-com"
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
  route53_zone_id = "Z18NSONI21UYAE"
}

resource "aws_route53_record" "howto" {
  zone_id = var.route53_zone_id
  name    = "howto"
  type    = "CNAME"
  records = ["cname.vercel-dns.com."]
}