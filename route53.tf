resource "aws_route53_delegation_set" "main" {
  reference_name = "prowler_nameserver_group"
}

resource "aws_route53_zone" "prowlersite" {
  name = var.prowlersite_domain
  delegation_set_id = aws_route53_delegation_set.main.id
}

data "aws_route53_zone" "this" {
  name = var.prowlersite_domain
}
resource "aws_route53_record" "dashboard" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "dashboard.prowler.${var.prowlersite_domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.dashboard.domain_name
    zone_id                = aws_cloudfront_distribution.dashboard.hosted_zone_id
    evaluate_target_health = false
  }
}