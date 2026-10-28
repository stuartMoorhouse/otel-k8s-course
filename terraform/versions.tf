terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    ec = {
      source  = "elastic/ec"
      version = "~> 0.13"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  # Mandatory org tags come from local.auto.tfvars (gitignored); never hardcode them.
  default_tags {
    tags = var.tags
  }
}

# Authenticates with the EC_API_KEY environment variable. The key, not Terraform,
# decides which Elastic Cloud organization the deployment is created in.
provider "ec" {}
