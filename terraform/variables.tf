variable "region" {
  description = "AWS region for everything"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "EKS cluster name, also used as a prefix for related resources"
  type        = string
  default     = "pcforge"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "VPC address range. Kept different from the runner VPC (10.0.0.0/16) so the two could be peered later."
  type        = string
  default     = "10.20.0.0/16"
}

variable "api_allowed_cidrs" {
  description = "Who may reach the public EKS API endpoint. Tighten to your runner's NAT IP, e.g. [\"1.2.3.4/32\"]."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_admin_role_name" {
  description = "IAM role that gets cluster-admin via an EKS access entry (the runner VM's role)"
  type        = string
  default     = "ec2-terraform-runner"
}

variable "github_owner" {
  description = "Your GitHub username; scopes the CI role to your pcforge repo only"
  type        = string

  validation {
    condition     = var.github_owner != "CHANGE_ME" && length(var.github_owner) > 0
    error_message = "Set github_owner in terraform.tfvars to your GitHub username."
  }
}

# GitHub's OIDC subject includes immutable numeric IDs: repo:<owner>@<owner_id>/<repo>@<repo_id>
variable "github_owner_id" {
  description = "Numeric GitHub account ID"
  type        = string
}

variable "infra_repo_id" {
  description = "Numeric ID of the platform-gitops repo"
  type        = string
}

variable "app_repo_id" {
  description = "Numeric ID of the pcforge repo"
  type        = string
}
