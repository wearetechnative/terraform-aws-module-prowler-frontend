output "prowler_frontend_hosted_zone_ns_servers" {
  value = aws_route53_zone.prowlersite.name_servers
}
