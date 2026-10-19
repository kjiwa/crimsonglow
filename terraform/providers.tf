terraform {
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.69.1"
    }
  }
}

provider "aws" {
  region              = "ca-central-1"
  allowed_account_ids = [var.account_id]
  default_tags { tags = var.default_tags }
}

# CloudFront only accepts ACM certificates issued in us-east-1.
provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  allowed_account_ids = [var.account_id]
  default_tags { tags = var.default_tags }
}
