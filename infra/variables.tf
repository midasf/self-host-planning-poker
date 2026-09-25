variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  type    = string
  default = "planning-poker"
}

variable "target_account_id" {
  type        = string
  description = "Workload account ID the app is deployed into (passed via buildspec)"
}

variable "target_account_role" {
  type        = string
  description = "Role assumed in the workload account (passed via buildspec)"
  default     = "OrganizationAccountAccessRole"
}

variable "waf_rate_limit" {
  description = "Max requests per 5-minute window from a single IP before WAF blocks it."
  type        = number
  default     = 2000
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "planning-poker"
    ManagedBy = "terraform"
  }
}
