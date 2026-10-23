# Route 53 answers DNS for the domain once GoDaddy points its nameservers here.
resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "Delegated from GoDaddy; records managed by Terraform (cert validation) and ExternalDNS (app hostnames)"
}

output "route53_name_servers" {
  description = "Put these 4 into GoDaddy: Domain -> DNS -> Nameservers -> use my own"
  value       = aws_route53_zone.main.name_servers
}
