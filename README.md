# platform-gitops

Platform repo for the PCForge lab: AWS infrastructure (Terraform) and, next, everything
Argo CD deploys into the cluster.

## What `terraform/` builds (eu-west-1)

| File | Creates |
|---|---|
| `vpc.tf` | VPC 10.20.0.0/16, 2 AZs, private /20s for nodes+pods, public /24s, 1 NAT Gateway, LB subnet tags |
| `eks.tf` | EKS 1.36, public+private API endpoint, access entry for the runner role, core add-ons, Spot node group (2x t3.medium), Pod Identity role for the AWS Load Balancer Controller |
| `ecr.tf` | `pcforge` ECR repo, immutable tags, scan on push, keep last 20 images |
| `github-oidc.tf` | GitHub OIDC provider + `pcforge-github-ci` role, assumable only by `main` of your `pcforge` repo, ECR push only |

## Run order

```bash
cd terraform
./bootstrap-state.sh                                   # once: S3 state bucket
vi terraform.tfvars                                    # set github_owner
terraform init -backend-config="bucket=pcforge-tfstate-$(aws sts get-caller-identity --query Account --output text)"
terraform plan -out=tfplan
terraform apply tfplan                                 # ~15 min, mostly the EKS control plane
$(terraform output -raw kubeconfig_command)
kubectl get nodes -o wide
```

## Teardown

Delete any Ingress first (or the Argo CD app that owns it) so the controller removes its ALB,
then `terraform destroy`. Otherwise the ALB's ENIs and security groups block VPC deletion.

Lab cost while running: roughly $0.20/hour (EKS control plane $0.10, NAT Gateway, 2 Spot nodes).
