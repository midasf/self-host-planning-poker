terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Applied manually (once) in the WORKLOAD account with admin credentials.
  backend "local" {}
}

provider "aws" {
  region = var.aws_region
}
