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

variable "lambda_reserved_concurrency" {
  description = "Reserved (and max) concurrent executions for the create + ws_default functions; bounds cost/DoS blast radius. -1 disables it (required on accounts with a low concurrency limit, where PutFunctionConcurrency would drop unreserved below the account minimum). Default is disabled; raise the account limit first, then set e.g. 25."
  type        = number
  default     = -1
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "planning-poker"
    ManagedBy = "terraform"
  }
}
