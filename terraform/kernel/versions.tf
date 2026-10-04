terraform {
  required_version = ">= 1.16.4, < 1.17.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "= 6.67.0" }
    github = { source = "integrations/github", version = "= 6.13.0" }
  }
  backend "s3" {}
}
provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
  default_tags { tags = { Project = "mads-hartmann.com", Stack = local.stack, ManagedBy = "Terraform" } }
}

provider "github" { owner = var.github_owner }
