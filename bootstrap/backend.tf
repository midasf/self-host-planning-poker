terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {}
}

# Bootstrap runs in the MANAGEMENT account (pipeline, state and artifacts live
# here). The application resources are created in the workload account by the
# infra/ stack via a cross-account assumed role.
provider "aws" {
  region = var.aws_region
}
