variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "repository_name" {
  type    = string
  default = "planning-poker"
}

variable "github_org" {
  type        = string
  description = "GitHub organization or user name"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for Terraform remote state (management account)"
}

variable "artifacts_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for CodePipeline artifacts (management account)"
}

variable "target_account_id" {
  type        = string
  description = "AWS account ID of the workload account where the app is deployed"
}

variable "target_account_role" {
  type        = string
  description = "Role in the workload account that CodeBuild/Terraform assume to deploy. Defaults to the scoped least-privilege role created by workload-bootstrap/ (apply that first). Override to OrganizationAccountAccessRole for the initial admin bootstrap."
  default     = "planning-poker-deploy"
}

variable "lambda_reserved_concurrency" {
  type        = number
  description = "Passed to infra/ as -var. Reserved (max) concurrency for the create + ws_default Lambdas. -1 disables it (default; required until the account's Lambda concurrency quota is raised). After the quota increase is approved, set e.g. 25 and re-apply bootstrap."
  default     = -1
}

variable "site_domain" {
  type        = string
  description = "URL used as the OWASP ZAP scan target (e.g. the CloudFront domain after the first deploy). Leave empty to skip a meaningful DAST target."
  default     = ""
}

variable "notification_email" {
  type    = string
  default = ""
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "planning-poker"
    ManagedBy = "terraform"
  }
}
