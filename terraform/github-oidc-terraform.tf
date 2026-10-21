# Two roles for running Terraform from GitHub Actions in the platform-gitops repo.
# They reuse the GitHub OIDC provider defined in github-oidc.tf.
#
#   tf-plan  : any pull request          -> read-only AWS + state lock    -> shows the plan
#   tf-apply : only the "production" GitHub environment on main -> admin -> changes AWS
#
# Splitting them means a PR (which anyone with push access can open, from any branch)
# can never change infrastructure; only reviewed code merged to main can.

locals {
  state_bucket = "pcforge-tfstate-${data.aws_caller_identity.current.account_id}"
  infra_repo   = "repo:${var.github_owner}@${var.github_owner_id}/platform-gitops@${var.infra_repo_id}"
}

# ---------- plan role ----------
data "aws_iam_policy_document" "tf_plan_trust" {
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
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.infra_repo}:pull_request"]
    }
  }
}

resource "aws_iam_role" "tf_plan" {
  name               = "${var.cluster_name}-tf-plan"
  assume_role_policy = data.aws_iam_policy_document.tf_plan_trust.json
}

resource "aws_iam_role_policy_attachment" "tf_plan_readonly" {
  role       = aws_iam_role.tf_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# plan takes the state lock, so it must be able to write and delete the .tflock object
data "aws_iam_policy_document" "tf_plan_lock" {
  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/platform/eks/terraform.tfstate.tflock"]
  }
}

resource "aws_iam_role_policy" "tf_plan_lock" {
  name   = "state-lock"
  role   = aws_iam_role.tf_plan.id
  policy = data.aws_iam_policy_document.tf_plan_lock.json
}

# ---------- apply role ----------
data "aws_iam_policy_document" "tf_apply_trust" {
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
    # Jobs that declare `environment: production` get this subject. The environment can
    # require a manual approval in GitHub before the job (and so this role) can run.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.infra_repo}:environment:production"]
    }
  }
}

resource "aws_iam_role" "tf_apply" {
  name               = "${var.cluster_name}-tf-apply"
  assume_role_policy = data.aws_iam_policy_document.tf_apply_trust.json
}

# Lab shortcut. Production: a custom policy limited to the services this stack manages,
# plus a permissions boundary so the role can't create roles more powerful than itself.
resource "aws_iam_role_policy_attachment" "tf_apply_admin" {
  role       = aws_iam_role.tf_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
