# workload-bootstrap — scoped deploy role (DRAFT / opt-in)

This is a **draft, not yet wired into the pipeline.** It replaces the pipeline's
use of `OrganizationAccountAccessRole` (full `AdministratorAccess`) with a
least-privilege role in the **workload account** that only grants what the
`infra/` Terraform + the frontend sync actually need.

## Why

Today the pipeline's CodeBuild role assumes `OrganizationAccountAccessRole` in
the workload account and runs `terraform apply` **and** `npm ci` (arbitrary
package lifecycle scripts) with admin. A compromised dependency or a malicious
change to a buildspec could do anything in the workload account. Scoping the
deploy role limits that blast radius.

## What it creates

`aws_iam_role.deploy` — assumable **only** by the management account's
`${repository_name}-codebuild` role — with an inline policy scoped (by
`project_name` ARNs where the service supports it) to: Lambda, API Gateway v2,
DynamoDB, S3 (the project buckets + object sync), CloudFront, WAFv2, IAM (only
`${project_name}*` roles), and CloudWatch Logs.

## How to adopt (deploy-test first!)

1. Apply this stack **once** in the workload account with admin creds:
   ```sh
   cd workload-bootstrap
   terraform init && terraform apply \
     -var=management_account_id=<MGMT_ACCT_ID>
   ```
2. Point the pipeline at the new role by setting, in `bootstrap/terraform.tfvars`:
   ```hcl
   target_account_role = "planning-poker-deploy"
   ```
   and re-apply `bootstrap/`.
3. **Validate with a real deploy.** `terraform apply` makes many describe/tag
   calls; if the pipeline fails with `AccessDenied`, add the missing action to
   `policy.tf` and re-apply this stack. Only after a clean end-to-end deploy
   should you consider the switch complete.

> Until step 2 is done, the pipeline keeps using `OrganizationAccountAccessRole`
> (the default), so nothing here affects current deploys.
