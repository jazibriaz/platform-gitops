# One certificate for the apex and every subdomain (app, argocd, ...), used by the ALBs.
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true # on replacement, issue the new cert before removing the old
  }
}

# ACM asks for a CNAME proving we control the domain; we write it into our own zone.
# The apex and the wildcard ask for the same record, hence allow_overwrite.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

# Waits until ACM reports the certificate as Issued.
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

output "acm_certificate_arn" {
  description = "Goes into the Ingress annotation alb.ingress.kubernetes.io/certificate-arn"
  value       = aws_acm_certificate_validation.main.certificate_arn
}
