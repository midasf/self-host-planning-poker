terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # State lives in the management account's bucket; the bucket/key/region are
  # supplied via -backend-config in buildspec-plan.yml / buildspec-apply.yml.
  backend "s3" {
    encrypt = true
  }
}
