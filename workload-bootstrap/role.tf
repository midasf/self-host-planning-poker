data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # The management-account CodeBuild role allowed to assume this deploy role.
  codebuild_role_arn = "arn:${local.partition}:iam::${var.management_account_id}:role/${var.repository_name}-codebuild"
}

resource "aws_iam_role" "deploy" {
  name = "${var.project_name}-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = local.codebuild_role_arn }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# Least-privilege policy for what infra/ manages + the frontend sync.
# NOTE: validate with a real pipeline deploy before switching the pipeline to
# this role — apply makes many describe/tag calls; add any missing action here.
resource "aws_iam_role_policy" "deploy" {
  name = "deploy-policy"
  role = aws_iam_role.deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Lambda"
        Effect   = "Allow"
        Action   = ["lambda:*"]
        Resource = "arn:${local.partition}:lambda:*:${local.account_id}:function:${var.project_name}*"
      },
      {
        # API Gateway v2 (HTTP + WebSocket) has no fine-grained resource ARNs
        # for most management calls.
        Sid      = "ApiGateway"
        Effect   = "Allow"
        Action   = ["apigateway:*"]
        Resource = "arn:${local.partition}:apigateway:*::/*"
      },
      {
        Sid    = "DynamoDB"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:DescribeTable",
          "dynamodb:UpdateTable",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:UpdateContinuousBackups",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:UpdateTimeToLive",
          "dynamodb:ListTagsOfResource",
          "dynamodb:TagResource",
          "dynamodb:UntagResource"
        ]
        Resource = "arn:${local.partition}:dynamodb:*:${local.account_id}:table/${var.project_name}*"
      },
      {
        # CloudFront + WAFv2 have no useful resource-level ARNs for most calls.
        Sid      = "CloudFrontWaf"
        Effect   = "Allow"
        Action   = ["cloudfront:*", "wafv2:*"]
        Resource = "*"
      },
      {
        Sid    = "S3Buckets"
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = [
          "arn:${local.partition}:s3:::${var.project_name}*",
          "arn:${local.partition}:s3:::${var.project_name}*/*"
        ]
      },
      {
        # data.aws_canonical_user_id (for the CloudFront log-bucket ACL) calls
        # s3:ListAllMyBuckets, which is only valid on resource "*".
        Sid      = "S3AccountRead"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets", "s3:GetBucketLocation"]
        Resource = "*"
      },
      {
        Sid    = "Iam"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PassRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags",
          "iam:ListInstanceProfilesForRole"
        ]
        Resource = "arn:${local.partition}:iam::${local.account_id}:role/${var.project_name}*"
      },
      {
        # First-time WAFv2 / CloudFront use in the account creates service-linked
        # roles (under role/aws-service-role/*, which the project-scoped statement
        # above does not match).
        Sid      = "IamServiceLinkedRoles"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "arn:${local.partition}:iam::${local.account_id}:role/aws-service-role/*"
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:ListTagsForResource",
          "logs:TagResource",
          "logs:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })
}
