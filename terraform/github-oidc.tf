# Lets GitHub Actions log in to AWS with short-lived OIDC tokens instead of stored access keys.
# Flow: GitHub signs a JWT for the workflow run -> AWS STS checks it against this provider
# -> the trust policy below checks WHICH repo and branch -> temporary credentials for ~1 hour.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # The important line: only the main branch of YOUR pcforge repo can assume this role.
    # Without it, any GitHub repo in the world could request credentials.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}@${var.github_owner_id}/pcforge@${var.app_repo_id}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_ci" {
  name               = "${var.cluster_name}-github-ci"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

# Least privilege: push images to the one pcforge repo, nothing else. No cluster access at all;
# in GitOps, CI never talks to Kubernetes, Argo CD pulls from Git.
data "aws_iam_policy_document" "github_ci" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # this API doesn't support resource-level scoping
  }

  statement {
    sid = "PushPcforge"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.pcforge.arn]
  }
}

resource "aws_iam_role_policy" "github_ci" {
  name   = "ecr-push-pcforge"
  role   = aws_iam_role.github_ci.id
  policy = data.aws_iam_policy_document.github_ci.json
}
