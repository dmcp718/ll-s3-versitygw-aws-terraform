# Create and validate wildcard ACM certificate for the domain name in Route53 hosted zone 
data "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_acm_certificate" "main" {
  domain_name = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "main" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
   # Skips the domain if it doesn't contain a wildcard
    if length(regexall("\\*\\..+", dvo.domain_name)) > 0
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

resource "aws_route53_record" "s3" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "s3"
  type    = "A"
  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "web" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "console"
  type    = "A"
  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}