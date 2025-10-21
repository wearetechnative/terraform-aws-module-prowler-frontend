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

  providers = {
    aws.us-east-1 : aws.us-east-1
  }
  depends_on = [aws_route53_zone.docsite]
}




module "prowler_scan" {
  source                       = "./prowler_scan"
  region                       = "eu-central-1"
  domain                       = var.prowlersite_domain
  prowler_scans                = {
        "regular_scan": {
            "prowler_schedule_timer": "cron(0 10 * * ? *)",
            "prowler_schedule_timezone":"Europe/Amsterdam",
            "prowler_scan_regions": ["eu-central-1"],
            "prowler_report_output_format": "csv",
            "task_definition_name": "prowler-security-assessment",
            "fargate_task_cpu": "512",
            "fargate_memory": "1024",
            
            "ecr_image_uri": "public.ecr.aws/prowler-cloud/prowler:latest",
            "prowler_account_list": ["489947827123"],
            "compliance_checks": [
                "aws_account_security_onboarding_aws",
                "aws_audit_manager_control_tower_guardrails_aws",
                "aws_foundational_security_best_practices_aws",
                "aws_foundational_technical_review_aws",
                "aws_well_architected_framework_reliability_pillar_aws",
                "aws_well_architected_framework_security_pillar_aws",
                "cis_1.4_aws",
                "cis_1.5_aws",
                "cis_2.0_aws",
                "cis_3.0_aws",
                "cisa_aws",
                "ens_rd2022_aws",
                "fedramp_low_revision_4_aws",
                "fedramp_moderate_revision_4_aws",
                "ffiec_aws",
                "gdpr_aws",
                "gxp_21_cfr_part_11_aws",
                "gxp_eu_annex_11_aws",
                "hipaa_aws",
                "iso27001_2013_aws",
                "kisa_isms_p_2023_aws",
                "kisa_isms_p_2023_korean_aws",
                "mitre_attack_aws",
                "nist_800_171_revision_2_aws",
                "nist_800_53_revision_4_aws",
                "nist_800_53_revision_5_aws",
                "nist_csf_1.1_aws",
                "pci_3.2.1_aws",
                "rbi_cyber_security_framework_aws",
                "soc2_aws"
            ],
            "severity": ["critical"]
        }
    }
  ecs_cluster_name             = "prowler-cluster"
  prowler_container_subnet     = "subnet-0cc828f8dbeb1b374"
  prowler_dashboard_subnet     = "subnet-0cc828f8dbeb1b374"
  vpc_id                       = "vpc-0f5064b0c3adad6e3"
  prowler_rolename_in_accounts = "prowler_role_test"
  prowler_report_bucket_name   = "jeroen-prowler-reports"
  container_name               = "prowler_scan"
  allowed_ips                  = ["217.123.196.236/32","82.172.137.171/32"]
  dashboard_uptime             = "30m"
  dashboard_frontend_url       = module.prowler_launch_website.url
  report_retention             = 7
  prowler_ami                  = "ami-0b6948208a73ed69c"
  kms_key_arn                  = "arn:aws:kms:eu-central-1:489947827123:key/ae32bbdd-a2e8-4d66-9bd1-a805de46364a"
  dlq_arn                      = "arn:aws:sqs:eu-central-1:489947827123:dlq-alert_gateway-20231005103150235300000002"
  cognito_id_provider_arns     = [module.prowler_launch_website.cognito_id_provider_arn]
  mutelist                     = file("./prowler_mutelist.yaml")
  depends_on = [aws_route53_zone.docsite]
}