locals {
  target_role_arn = "arn:aws:iam::${var.target_account_id}:role/${var.target_account_role}"
}

# App resources are created in the WORKLOAD account via an assumed role.
provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn = local.target_role_arn
  }
}

# CloudFront-scoped WAF Web ACLs must be created in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  assume_role {
    role_arn = local.target_role_arn
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}
