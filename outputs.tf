output "prowler_frontend_hosted_zone_ns_servers" {
  value = aws_route53_zone.prowlersite.name_servers
}

output "cognito_user_pool_id" {
  description = "ID of the Cognito user pool protecting the dashboard frontend"
  value       = module.prowler_launch_website.cognito_user_pool_id
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic that emits failed scan notifications"
  value       = module.prowler_scan.sns_topic_arn
}
