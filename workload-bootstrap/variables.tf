variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  type    = string
  default = "planning-poker"
}

variable "repository_name" {
  type        = string
  description = "Must match bootstrap/var.repository_name (used to build the CodeBuild role ARN that may assume this role)."
  default     = "planning-poker"
}

variable "management_account_id" {
  type        = string
  description = "AWS account ID of the management account that runs the pipeline."
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "planning-poker"
    ManagedBy = "terraform"
  }
}
