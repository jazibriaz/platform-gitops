locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2) # EKS needs at least 2 AZs
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  # Private /20s (4,096 IPs each): nodes AND pods live here, because the VPC CNI
  # gives every pod a real VPC IP. Size these generously; IP exhaustion is the classic EKS failure.
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)] # 10.20.0.0/20, 10.20.16.0/20
  # Public /24s: only the NAT Gateway and internet-facing ALBs live here.
  public_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, 100 + i)] # 10.20.100.0/24, 10.20.101.0/24

  enable_nat_gateway = true
  single_nat_gateway = true # one NAT for the lab (~$1/day). Production: one per AZ so an AZ outage doesn't cut egress.

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags the AWS Load Balancer Controller reads to decide where to put load balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1" # internet-facing ALBs
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1" # internal ALBs/NLBs
  }
}
