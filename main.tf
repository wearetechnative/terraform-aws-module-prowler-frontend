module "prowler_launch_website" {

  source                         = "./prowler_frontend"
  name                           = var.prowlersite_name
  domain                         = "${var.prowlersite_name}.${var.prowlersite_domain}"
  route53_zone_name              = var.prowlersite_domain
  deploy_user_name               = "prowler-deployer-user"
  cognito_path_refresh_auth      = "/refreshauth"
  cognito_path_logout            = "/logout"
  cognito_path_parse_auth        = "/parseauth"
  cognito_refresh_token_validity = 3650
  cognito_domain_prefix          = "login"
  cognito_additional_callbacks   = [
    "https://login.prowler.${var.prowlersite_domain}",
    "https://prowler.${var.prowlersite_domain}",
    "https://dashboard.prowler.${var.prowlersite_domain}"
  ]
  api_gateway_stage_invoke_url = module.prowler_scan.api_gateway_stage_invoke_url
  cloudfront_secret            = local.cloudfront_secret
  alb_dns                      = module.prowler_scan.alb_dns
  providers = {
    aws.us-east-1 : aws.us-east-1
  }
  depends_on = [aws_route53_zone.prowlersite]
}

resource "random_password" "cloudfront_secret" {
  length  = 32
  special = false
}

module "prowler_scan" {
  source                       = "./prowler_scan"
  region                       = var.region
  domain                       = var.prowlersite_domain
  prowler_scans                = var.prowler_scans
  ecs_cluster_name             = var.ecs_cluster_name
  prowler_container_subnet     = var.prowler_container_subnet
  prowler_dashboard_subnet     = var.prowler_dashboard_subnet
  vpc_id                       = var.vpc_id
  prowler_rolename_in_accounts = var.prowler_rolename_in_accounts
  prowler_report_bucket_name   = var.prowler_report_bucket_name
  container_name               = var.container_name
  allowed_ips                  = var.allowed_ips
  dashboard_uptime             = var.dashboard_uptime
  dashboard_frontend_url       = module.prowler_launch_website.url
  report_retention             = var.report_retention
  prowler_ami                  = var.prowler_ami
  kms_key_arn                  = var.kms_key_arn
  dlq_arn                      = var.dlq_arn
  cognito_id_provider_arns     = [module.prowler_launch_website.cognito_id_provider_arn]
  mutelist                     = var.mutelist
  cloudfront_secret            = local.cloudfront_secret 
  depends_on = [aws_route53_zone.prowlersite]
}