# workload-bootstrap — scoped deploy role

Replaces the pipeline's use of `OrganizationAccountAccessRole` (full
`AdministratorAccess`) with a least-privilege role in the **workload account**
that only grants what the `infra/` Terraform + the frontend sync actually need.

`bootstrap/var.target_account_role` now **defaults to `planning-poker-deploy`**
(the role this stack creates), so you must apply this stack before the pipeline
can deploy. The policy has been audited against every resource in `infra/`; the
first real apply may still surface an action or two to add (see step 4).

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

## How to adopt

Run these with **workload-account admin** creds for step 1 and **management-account**
creds for step 2 (the pipeline can't create its own deploy role).

1. Create the scoped role in the **workload account**:
   ```sh
   cd workload-bootstrap
   terraform init && terraform apply -var=management_account_id=<MGMT_ACCT_ID>
   ```
2. Re-apply `bootstrap/` in the **management account** so CodeBuild switches to
   the scoped role (it's already the default now):
   ```sh
   cd ../bootstrap && terraform apply
   ```
3. Trigger a deploy (push to `main`) — the pipeline's `infra/` apply now runs as
   `planning-poker-deploy`.
4. **Validate:** if that apply fails with `AccessDenied`, add the named action to
   `role.tf` and re-apply this stack, then re-run the pipeline. Repeat until a
   clean end-to-end deploy. Only then retire `OrganizationAccountAccessRole`.

> Rollback: set `target_account_role = "OrganizationAccountAccessRole"` when
> applying `bootstrap/` to revert the pipeline to the admin role.
