resource "aws_route53_delegation_set" "main" {
  reference_name = "prowler_nameserver_group"
}

resource "aws_route53_zone" "prowlersite" {
  name              = var.prowlersite_domain
  delegation_set_id = aws_route53_delegation_set.main.id
}
