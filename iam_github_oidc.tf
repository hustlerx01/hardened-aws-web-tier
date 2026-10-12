# GitHub Actions -> AWS without long-lived keys.
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_github_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # AWS no longer checks this for GitHub, but the API needs a value
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_role" "github_plan" {
  name                 = "${var.project}-github-plan"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          # exact repo + branch, plus PRs from this repo. No wildcards on the owner.
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_repo}:ref:refs/heads/${var.github_branch}",
            "repo:${var.github_repo}:pull_request"
          ]
        }
      }
    }]
  })
}

# Read-only: enough for `terraform plan`, nothing that can change infrastructure.
# Describe/List APIs don't support resource-level scoping, hence Resource "*" (see SECURITY_FINDINGS.md).
#tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_policy" "github_plan" {
  name        = "${var.project}-github-plan"
  description = "Read-only permissions for terraform plan from GitHub Actions"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DescribeForPlan"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "autoscaling:Describe*",
          "iam:GetRole", "iam:GetRolePolicy", "iam:GetPolicy", "iam:GetPolicyVersion",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:GetInstanceProfile",
          "iam:GetOpenIDConnectProvider", "iam:ListOpenIDConnectProviders",
          "cloudtrail:DescribeTrails", "cloudtrail:GetTrailStatus", "cloudtrail:GetEventSelectors", "cloudtrail:ListTags",
          "guardduty:GetDetector", "guardduty:ListDetectors",
          "kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus", "kms:ListAliases", "kms:ListResourceTags",
          "logs:DescribeLogGroups", "logs:ListTagsForResource",
          "ssm:GetParameter",
          "s3:GetBucket*", "s3:GetEncryptionConfiguration", "s3:GetLifecycleConfiguration",
          "s3:GetAccelerateConfiguration", "s3:GetReplicationConfiguration", "s3:ListBucket",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Sid      = "ReadState"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = ["arn:${data.aws_partition.current.partition}:s3:::${var.tf_state_bucket}", "arn:${data.aws_partition.current.partition}:s3:::${var.tf_state_bucket}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_plan" {
  role       = aws_iam_role.github_plan.name
  policy_arn = aws_iam_policy.github_plan.arn
}
