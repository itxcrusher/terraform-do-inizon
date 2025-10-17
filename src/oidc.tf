#######################################################################
# GitHub OIDC → AWS role for Terraform state (S3/DynamoDB)
# Reads region/profile/account/bucket/table exclusively from locals.
#######################################################################

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "gha_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.github.owner}/${local.github.repo}:ref:refs/heads/${local.github.main_branch}",
        "repo:${local.github.owner}/${local.github.repo}:pull_request"
      ]
    }
  }
}

resource "aws_iam_role" "gha_terraform" {
  name               = "Do-GitHubOIDC-TerraformRole"
  assume_role_policy = data.aws_iam_policy_document.gha_trust.json
}

data "aws_iam_policy_document" "tf_state_access" {
  # S3 state bucket
  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${local.backend.bucket}"]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.backend.bucket}/*"]
  }
  # Optional idempotent bucket hardening
  statement {
    actions   = ["s3:CreateBucket", "s3:PutBucketVersioning", "s3:PutBucketEncryption", "s3:PutPublicAccessBlock"]
    resources = ["arn:aws:s3:::${local.backend.bucket}"]
  }
  # DynamoDB lock table (required when use_lockfile=true)
  statement {
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:UpdateItem",
      "dynamodb:DescribeTable", "dynamodb:CreateTable", "dynamodb:ListTables"
    ]
    resources = ["arn:aws:dynamodb:${local.backend.region}:${local.backend.account_id}:table/${local.backend.dynamodb_table}"]
  }
  # OIDC provider reads
  statement {
    actions   = ["iam:GetOpenIDConnectProvider"]
    resources = ["arn:aws:iam::${local.backend.account_id}:oidc-provider/token.actions.githubusercontent.com"]
  }
  statement {
    actions   = ["iam:ListOpenIDConnectProviders"]
    resources = ["*"]
  }
  # Manage this role’s attachments
  statement {
    actions = [
      "iam:GetRole", "iam:UpdateAssumeRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies", "iam:ListRolePolicies", "iam:GetRolePolicy"
    ]
    resources = ["arn:aws:iam::${local.backend.account_id}:role/${aws_iam_role.gha_terraform.name}"]
  }
  # Create/Version the managed policy
  statement {
    actions   = ["iam:CreatePolicy"]
    resources = ["*"]
  }
  statement {
    actions = [
      "iam:GetPolicy", "iam:CreatePolicyVersion", "iam:ListPolicyVersions",
      "iam:GetPolicyVersion", "iam:SetDefaultPolicyVersion", "iam:DeletePolicyVersion"
    ]
    resources = ["arn:aws:iam::${local.backend.account_id}:policy/TerraformStateAccess-DO"]
  }
}

resource "aws_iam_policy" "tf_state_access" {
  name   = "TerraformStateAccess-DO"
  policy = data.aws_iam_policy_document.tf_state_access.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.gha_terraform.name
  policy_arn = aws_iam_policy.tf_state_access.arn
}
