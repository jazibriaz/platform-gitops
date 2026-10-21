module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.25"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # nodes and control-plane ENIs go in private subnets

  # API endpoint: public (so the runner in another VPC can reach it) AND private
  # (so nodes talk to the control plane inside the VPC, never via the internet).
  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = var.api_allowed_cidrs

  # Access entries replace the old aws-auth ConfigMap.
  # NOT "make whoever runs Terraform the admin": once CI runs Terraform, that would hand
  # cluster-admin to the CI role and silently remove it from the runner. Admins are named
  # explicitly instead. The key "cluster_creator" and policy key "admin" match the entry
  # the module created on the first apply, so this change is a no-op for the existing entry.
  enable_cluster_creator_admin_permissions = false

  access_entries = {
    cluster_creator = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_admin_role_name}"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    console_viewer = {
      principal_arn = "arn:aws:iam::833167447551:root"
      policy_associations = {
        view = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Core add-ons managed by EKS. vpc-cni and the pod-identity agent must exist before
  # nodes join, otherwise pods have no networking and no AWS credentials.
  addons = {
    vpc-cni = {
      before_compute = true
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    coredns    = {}
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "SPOT"                      # ~70% cheaper; fine for a lab, AWS can reclaim it
      instance_types = ["t3.medium", "t3a.medium"] # 2 types = more Spot pools = fewer interruptions

      min_size     = 2
      desired_size = 2
      max_size     = 3

      labels = {
        workload = "general"
      }
    }
  }
}

# IAM role for the AWS Load Balancer Controller, handed to its pod via EKS Pod Identity.
# Terraform owns the AWS side (role + policy + association); Argo CD will install the chart.
module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.9"

  name                            = "${var.cluster_name}-aws-lbc"
  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller" # must match the Helm chart's service account name
    }
  }
}
