# Terraform AWS Prowler Frontend

This module deploys a complete Prowler scanning stack on AWS:

- Scheduled Prowler scans on ECS Fargate
- API Gateway + Lambda endpoints to start scans and launch the dashboard
- Cognito-protected frontend on CloudFront
- ALB + EC2-backed Prowler dashboard
- SNS notifications for failed checks

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

The dashboard AMI can be prepared from Ubuntu using:

```bash
sudo apt update -y
sudo apt install pipx unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
pipx install prowler
pipx ensurepath
```

### 2. Target account role (create before first scan run)

Each target account needs an IAM role that Prowler can assume. The role name
must match `var.prowler_rolename_in_accounts`.

You can deploy this module first to create the scanner account role
(`prowler_task_role`), then create/update trust in target accounts to that role
before the first scheduled scan executes.

Important: if `prowler_rolename_in_accounts` is `"prowler_scan_role"`, the role
in every target account must also be named `"prowler_scan_role"`.

Example for target accounts:

```hcl
variable "scanner_account_id" {
  type = string
}

resource "aws_iam_role" "prowler_execution" {
  name = "prowler_scan_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          AWS = "arn:aws:iam::${var.scanner_account_id}:role/prowler_task_role"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "security_audit" {
  role       = aws_iam_role.prowler_execution.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}
```

## Usage

### 1. Configure providers

This module requires an AWS provider alias for `us-east-1` because Lambda@Edge
and ACM resources for CloudFront are created there.

```hcl
terraform {
  required_version = ">= 1.0.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.9.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}
```

### 2. Deploy the module

The value of `prowler_rolename_in_accounts` must exactly match the target
account IAM role name shown in the previous section.

Deployment order:

1. Apply this module in the scanner account.
2. Create/update the target-account role trust to `prowler_task_role` from the scanner account.
3. Run scans (manually or on schedule).

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
  prowler_ami                  = "ami-0abc123def4567890"
  allowed_ips                  = ["203.0.113.10/32"]
  dashboard_uptime             = "1h"
  kms_key_arn                  = "arn:aws:kms:eu-west-1:123456789012:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  dlq_arn                      = "arn:aws:sqs:eu-west-1:123456789012:prowler-lambda-dlq"

  prowler_scans = {
    nightly = {
      prowler_schedule_timer       = "cron(0 1 * * ? *)"
      prowler_schedule_timezone    = "UTC"
      prowler_scan_regions         = ["eu-west-1"]
      prowler_report_output_format = "csv" # And/or "html", "json"
      task_definition_name         = "prowler-nightly"
      fargate_task_cpu             = "1024"
      fargate_memory               = "2048"
      ecr_image_uri                = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/prowler:latest"
      prowler_account_list         = ["111122223333", "444455556666"]
      compliance_checks            = ["cis_aws"]
      severity                     = ["HIGH", "MEDIUM"]
    }
  }
}
```

### 3. Delegate DNS

The module creates a hosted zone for `prowlersite_domain` and outputs its name
servers as `prowler_frontend_hosted_zone_ns_servers`. Delegate those NS records
in your parent DNS zone so the frontend and dashboard records resolve.

### 4. Create a Cognito user for the dashboard

```bash
aws cognito-idp admin-create-user \
  --user-pool-id <cognito_user_pool_id> \
  --username security@example.com \
  --user-attributes Name=email,Value=security@example.com \
  --temporary-password 'Prowler#2024'
```

The user pool ID is available via:

```bash
terraform output -raw cognito_user_pool_id
```

### 5. Subscribe to SNS notifications

```bash
aws sns subscribe \
  --topic-arn "$(terraform output -raw sns_topic_arn)" \
  --protocol email \
  --notification-endpoint secops@example.com
```

Confirm the subscription from the email AWS sends.

## Operational Notes

- The dashboard EC2 instance is temporary and auto-terminates after
  `dashboard_uptime`.
- Current dashboard behavior: it copies reports from S3 at startup and reads the
  local directory once. New scan results written to S3 after startup are not
  visible until you launch a new dashboard instance.
- If you need continuously fresh results, use an external sync/restart strategy
  or move the dashboard runtime to a containerized model that refreshes data.


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
