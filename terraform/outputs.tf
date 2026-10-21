output "cluster_name" {
  value = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Run this to point kubectl at the new cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ecr_repository_url" {
  description = "Goes into the kustomize overlays' images.newName"
  value       = aws_ecr_repository.pcforge.repository_url
}

output "github_ci_role_arn" {
  description = "Goes into the GitHub Actions workflow (role-to-assume)"
  value       = aws_iam_role.github_ci.arn
}

output "tf_plan_role_arn" {
  value = aws_iam_role.tf_plan.arn
}

output "tf_apply_role_arn" {
  value = aws_iam_role.tf_apply.arn
}

output "aws_lb_controller_role_arn" {
  value = module.aws_lb_controller_pod_identity.iam_role_arn
}
