# Terraform AWS [Prowler] ![](https://img.shields.io/github/actions/workflow/status/wearetechnative/terraform-aws-iam-user/tflint.yaml?style=plastic)

<!-- SHIELDS -->

This module implements ...

[![](we-are-technative.png)](https://www.technative.nl)

## How does it work

### First use after you clone this repository or when .pre-commit-config.yaml is updated

Run `pre-commit install` to install any guardrails implemented using pre-commit.

See [pre-commit installation](https://pre-commit.com/#install) on how to install pre-commit.

...

## Usage

### 1. Prepare a Prowler-ready AMI

The EC2 dashboard instance bootstraps significantly faster when Prowler and its
dependencies are already available on the image. When using an Ubuntu base AMI,
install the tools shown below and register the resulting AMI in the account in
which you run this module.

```
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

  region                     = "eu-west-1"
  prowlersite_domain         = "example.com"
  vpc_id                     = "vpc-0123456789abcdef0"
  ecs_cluster_name           = "prowler"
  container_name             = "prowler"
  prowler_report_bucket_name = "prowler-reports-example"
  prowler_rolename_in_accounts = "ProwlerExecutionRole"
  prowler_ami                  = "ami-0abc123def4567890"
  allowed_ips                = ["203.0.113.10/32"]
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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.96.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_api_endpoints"></a> [api\_endpoints](#module\_api\_endpoints) | ./modules/api_gateway | n/a |
| <a name="module_ec2_instance_role"></a> [ec2\_instance\_role](#module\_ec2\_instance\_role) | git@github.com:wearetechnative/terraform-aws-iam-role | 0fe916c27097706237692122e09f323f55e8237e |
| <a name="module_iam_role_lambda_prowler"></a> [iam\_role\_lambda\_prowler](#module\_iam\_role\_lambda\_prowler) | git@github.com:wearetechnative/terraform-aws-iam-role.git | 9229bbd0280807cbc49f194ff6d2741265dc108a |
| <a name="module_iam_role_lambda_prowler_failed_task"></a> [iam\_role\_lambda\_prowler\_failed\_task](#module\_iam\_role\_lambda\_prowler\_failed\_task) | git@github.com:wearetechnative/terraform-aws-iam-role.git | 9229bbd0280807cbc49f194ff6d2741265dc108a |
| <a name="module_iam_role_lambda_terminate_dashboard"></a> [iam\_role\_lambda\_terminate\_dashboard](#module\_iam\_role\_lambda\_terminate\_dashboard) | git@github.com:wearetechnative/terraform-aws-iam-role.git | 9229bbd0280807cbc49f194ff6d2741265dc108a |
| <a name="module_key_pair"></a> [key\_pair](#module\_key\_pair) | terraform-aws-modules/key-pair/aws | 2.0.2 |
| <a name="module_lambda_prowler"></a> [lambda\_prowler](#module\_lambda\_prowler) | git@github.com:wearetechnative/terraform-aws-lambda.git | 13eda5f9e8ae40e51f66a45837cd41a6b35af988 |
| <a name="module_lambda_prowler_failed_task"></a> [lambda\_prowler\_failed\_task](#module\_lambda\_prowler\_failed\_task) | git@github.com:wearetechnative/terraform-aws-lambda.git | 13eda5f9e8ae40e51f66a45837cd41a6b35af988 |
| <a name="module_lambda_terminate_dashboard"></a> [lambda\_terminate\_dashboard](#module\_lambda\_terminate\_dashboard) | git@github.com:wearetechnative/terraform-aws-lambda.git | 13eda5f9e8ae40e51f66a45837cd41a6b35af988 |
| <a name="module_prowler"></a> [prowler](#module\_prowler) | ./modules/scan | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_api_gateway_authorizer.prowler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_authorizer) | resource |
| [aws_api_gateway_deployment.prowler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_deployment) | resource |
| [aws_api_gateway_rest_api.prowler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) | resource |
| [aws_api_gateway_stage.prod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_stage) | resource |
| [aws_cloudwatch_event_rule.failed_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.terminate_schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.failed_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.lambda_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.prowler_cw_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.prowler_ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_iam_instance_profile.ec2_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.dashboard_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.executionrole](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.schedulerole](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.taskrole](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.allow_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.allow_passrole_schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.update_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.dashboard_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecr-policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task-execution-policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_permission.allow_all_apigateway_calls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.allow_eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.failed_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_launch_template.compute](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.dashboard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.dashboard_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.dashboard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.dashboard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.prowler_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.reports](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.allow_access_from_another_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.public_access_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_versioning.bucket_versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_object.mutelist](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_security_group.alb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.dashboard_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.prowler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.alb_to_dashboard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.dashboard_cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.inbound_dashboard_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.inbound_ssh_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.outbound_dashboard_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.prowler_out](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_sns_topic.check_fail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.check_fail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [null_resource.stage_blocker](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_iam_policy_document.allow_getobject_from_other_accounts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.dashboard_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_list_tasks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_pass_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_run_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.launch_dashboard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.publish_failed_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.sns_topic_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.terminate_dashboard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.update_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_ips"></a> [allowed\_ips](#input\_allowed\_ips) | ips allowed to access prowler dashboard (add /32 to ips) | `list(string)` | n/a | yes |
| <a name="input_cognito_id_provider_arns"></a> [cognito\_id\_provider\_arns](#input\_cognito\_id\_provider\_arns) | List of arns of cognito identity providers you want to allow to run prowler scans | `list(any)` | n/a | yes |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Name of the Container within AWS Fargate | `string` | n/a | yes |
| <a name="input_dashboard_frontend_url"></a> [dashboard\_frontend\_url](#input\_dashboard\_frontend\_url) | Frontend page to launch dashboard from | `string` | n/a | yes |
| <a name="input_dashboard_uptime"></a> [dashboard\_uptime](#input\_dashboard\_uptime) | Running time of prowler dashboard ec2, will self-terminate after certain amount of time (1d, 1h, 2h, 15m) | `string` | `"1h"` | no |
| <a name="input_dlq_arn"></a> [dlq\_arn](#input\_dlq\_arn) | ARN for DLQ for lambda | `string` | n/a | yes |
| <a name="input_domain"></a> [domain](#input\_domain) | Domain for dashboard dns record | `string` | n/a | yes |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name) | Name of cluster | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of kms key for lambda | `string` | n/a | yes |
| <a name="input_mutelist"></a> [mutelist](#input\_mutelist) | Contents of the mutelist yaml file | `string` | `"Mutelist: []"` | no |
| <a name="input_prowler_ami"></a> [prowler\_ami](#input\_prowler\_ami) | AMI id with prowler pre-installed (fast boot time) | `string` | n/a | yes |
| <a name="input_prowler_container_subnet"></a> [prowler\_container\_subnet](#input\_prowler\_container\_subnet) | Provide a Subnet ID to launch Prowler container | `string` | n/a | yes |
| <a name="input_prowler_dashboard_subnet"></a> [prowler\_dashboard\_subnet](#input\_prowler\_dashboard\_subnet) | Provide a Subnet ID to launch Prowler dashboard | `string` | `""` | no |
| <a name="input_prowler_report_bucket_name"></a> [prowler\_report\_bucket\_name](#input\_prowler\_report\_bucket\_name) | Name of the bucket where output reports are saved | `string` | n/a | yes |
| <a name="input_prowler_rolename_in_accounts"></a> [prowler\_rolename\_in\_accounts](#input\_prowler\_rolename\_in\_accounts) | Name of the role in all the accounts that prowler assumes to scan | `string` | n/a | yes |
| <a name="input_prowler_scans"></a> [prowler\_scans](#input\_prowler\_scans) | prowler config | <pre>map(object({<br>    prowler_schedule_timer       = string<br>    prowler_schedule_timezone    = string<br>    prowler_scan_regions         = list(string)<br>    prowler_report_output_format = string<br>    task_definition_name         = string<br>    fargate_task_cpu             = string<br>    fargate_memory               = string<br>    ecr_image_uri                = string<br>    prowler_account_list         = list(string)<br>    compliance_checks            = list(string)<br>    severity                     = list(string)<br>  }))</pre> | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region to deploy the resources. | `string` | n/a | yes |
| <a name="input_report_retention"></a> [report\_retention](#input\_report\_retention) | Number of days to retain prowler reports in bucket | `number` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Provide a VPC ID where prowler\_container\_subnet resides | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_gateway_stage_invoke_url"></a> [api\_gateway\_stage\_invoke\_url](#output\_api\_gateway\_stage\_invoke\_url) | n/a |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | n/a |
| <a name="output_eip_allocation_id"></a> [eip\_allocation\_id](#output\_eip\_allocation\_id) | n/a |
<!-- END_TF_DOCS -->
