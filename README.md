# Terraform AWS [Prowler] ![](https://img.shields.io/github/actions/workflow/status/wearetechnative/terraform-aws-iam-user/tflint.yaml?style=plastic)

<!-- SHIELDS -->

This module implements ...

[![](we-are-technative.png)](https://www.technative.nl)

## Prerequisites

Before deploying this module, ensure the following resources and setup exist.

### 1. Scanner account prerequisites

- A VPC with at least one public subnet (`map_public_ip_on_launch = true`)
- A KMS key for Lambda encryption (`kms_key_arn`)
- An SQS dead-letter queue for Lambda (`dlq_arn`)
- A domain name for the frontend, for example `prowler.example.com`
- An ECR image containing Prowler
- A Prowler-ready AMI for the dashboard EC2 instance (`prowler_ami`)


There is a public AMI: ami-06d17b909aa1698bb, it has prowler preinstalled and is ready to use out of the box.

A dashboard AMI can also be prepared from Ubuntu using:

```bash
sudo apt update -y
sudo apt install pipx unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
pipx install prowler
pipx ensurepath
```

### 2. Deploy the module

Reference this repository from your Terraform configuration and provide the
required inputs for both the scan backend and the Cognito-protected frontend
(VPC, Route53 zone, bucket name, scan definitions, etc.).

```hcl
module "prowler_stack" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-prowler-frontend.git?ref=<release>"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  region                       = "eu-west-1"
  prowlersite_name             = "prowler"
  prowlersite_domain           = "prowler.example.com"
  vpc_id                       = "vpc-0123456789abcdef0"
  ecs_cluster_name             = "prowler"
  container_name               = "prowler"
  prowler_report_bucket_name   = "prowler-reports-example"
  prowler_rolename_in_accounts = "prowler_scan_role"
  report_retention             = 30
  prowler_ami                  = "ami-06d17b909aa1698bb"
  allowed_ips                  = ["10.10.10.10/32"] # ssh access to dashboard instance
  dashboard_uptime             = "30m"
  kms_key_arn                  = "arn:aws:kms:eu-west-1:123456789012:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  dlq_arn                      = "arn:aws:sqs:eu-west-1:123456789012:prowler-lambda-dlq"

  prowler_scans = {
    nightly = {
      prowler_schedule_timer       = "cron(0 1 * * ? *)"
      prowler_schedule_timezone    = "UTC"
      prowler_scan_regions         = ["eu-west-1"]
      prowler_report_output_format = "csv"
      task_definition_name         = "prowler-nightly"
      fargate_task_cpu             = "1024"
      fargate_memory               = "2048"
      ecr_image_uri                = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/prowler:latest"
      prowler_account_list         = ["111122223333"]
      compliance_checks            = ["cis_aws"]
      severity                     = ["HIGH", "MEDIUM"]
    }
  }

  # See variables.tf for the remaining inputs such as kms_key_arn, dlq_arn, etc.
}
```

Run `terraform init`, `terraform plan`, and `terraform apply` to provision the
scan pipeline, API Gateway, Cognito user pool, CloudFront distribution, and the
dashboard infrastructure.

### 3. Create a Cognito user for the dashboard

Only authenticated Cognito users can open the dashboard or trigger scans. After
the infrastructure is deployed, create at least one user in the Cognito user
pool that the module created (its name is derived from `var.prowlersite_name`).
This can be done through the AWS Console or the CLI:

```
aws cognito-idp admin-create-user \
  --user-pool-id <cognito_user_pool_id> \
  --username security@example.com \
  --user-attributes Name=email,Value=security@example.com \
  --temporary-password 'Prowler#2024'
```

Replace `<cognito_user_pool_id>` with the ID of the Cognito pool shown in the
Amazon Cognito console (or obtained from Terraform state via
`terraform output -raw cognito_user_pool_id`). Share the temporary
password with the intended operator so they can update it at first login.

### 4. Subscribe to the SNS topic for scan notifications

The module creates an SNS topic named `prowler_security_check_fail_notifier`
that receives events whenever a scan finishes with failing checks. Subscribe
your operations mailbox (or another notification target) so you receive those
alerts:

```
aws sns subscribe \
  --topic-arn <topic_arn> \
  --protocol email \
  --notification-endpoint secops@example.com
```

The topic ARN is visible in the Amazon SNS console or through the Terraform
state using `terraform output -raw sns_topic_arn`. Confirm the subscription from
the email that AWS sends. Without this step you will not receive alerts
about failed scans.


<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_prowler_launch_website"></a> [prowler\_launch\_website](#module\_prowler\_launch\_website) | ./prowler_frontend | n/a |
| <a name="module_prowler_scan"></a> [prowler\_scan](#module\_prowler\_scan) | ./prowler_scan | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_route53_delegation_set.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_delegation_set) | resource |
| [aws_route53_zone.prowlersite](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnets.all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_ips"></a> [allowed\_ips](#input\_allowed\_ips) | ips allowed to access prowler dashboard (add /32 to ips) | `list(string)` | n/a | yes |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Name of the Container within AWS Fargate | `string` | n/a | yes |
| <a name="input_dashboard_uptime"></a> [dashboard\_uptime](#input\_dashboard\_uptime) | Running time of prowler dashboard ec2, will self-terminate after certain amount of time (1d, 1h, 2h, 15m) | `string` | `"1h"` | no |
| <a name="input_dlq_arn"></a> [dlq\_arn](#input\_dlq\_arn) | ARN for DLQ for lambda | `string` | n/a | yes |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name) | Name of cluster | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of kms key for lambda | `string` | n/a | yes |
| <a name="input_mutelist"></a> [mutelist](#input\_mutelist) | Contents of the mutelist yaml file | `string` | `"Mutelist: []"` | no |
| <a name="input_prowler_ami"></a> [prowler\_ami](#input\_prowler\_ami) | AMI id with prowler pre-installed (fast boot time) | `string` | n/a | yes |
| <a name="input_prowler_report_bucket_name"></a> [prowler\_report\_bucket\_name](#input\_prowler\_report\_bucket\_name) | Name of the bucket where output reports are saved | `string` | n/a | yes |
| <a name="input_prowler_rolename_in_accounts"></a> [prowler\_rolename\_in\_accounts](#input\_prowler\_rolename\_in\_accounts) | Name of the role in all the accounts that prowler assumes to scan | `string` | n/a | yes |
| <a name="input_prowler_scans"></a> [prowler\_scans](#input\_prowler\_scans) | prowler config | <pre>map(object({<br>    prowler_schedule_timer       = string<br>    prowler_schedule_timezone    = string<br>    prowler_scan_regions         = list(string)<br>    prowler_report_output_format = string<br>    task_definition_name         = string<br>    fargate_task_cpu             = string<br>    fargate_memory               = string<br>    ecr_image_uri                = string<br>    prowler_account_list         = list(string)<br>    compliance_checks            = list(string)<br>    severity                     = list(string)<br>  }))</pre> | n/a | yes |
| <a name="input_prowlersite_domain"></a> [prowlersite\_domain](#input\_prowlersite\_domain) | Fully qualified domain for the dashboard and frontend (for example, prowler.example.com) | `string` | n/a | yes |
| <a name="input_prowlersite_name"></a> [prowlersite\_name](#input\_prowlersite\_name) | Name for the frontend module | `string` | `"prowler"` | no |
| <a name="input_region"></a> [region](#input\_region) | Region to deploy the resources. | `string` | n/a | yes |
| <a name="input_report_retention"></a> [report\_retention](#input\_report\_retention) | Number of days to retain prowler reports in bucket | `number` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Provide a VPC ID where prowler\_container\_subnet resides | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cognito_user_pool_id"></a> [cognito\_user\_pool\_id](#output\_cognito\_user\_pool\_id) | ID of the Cognito user pool protecting the dashboard frontend |
| <a name="output_prowler_frontend_hosted_zone_ns_servers"></a> [prowler\_frontend\_hosted\_zone\_ns\_servers](#output\_prowler\_frontend\_hosted\_zone\_ns\_servers) | n/a |
| <a name="output_sns_topic_arn"></a> [sns\_topic\_arn](#output\_sns\_topic\_arn) | ARN of the SNS topic that emits failed scan notifications |
<!-- END_TF_DOCS -->
