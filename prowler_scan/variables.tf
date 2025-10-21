variable "region" {
  description = "Region to deploy the resources."
  type        = string
}

variable "prowler_rolename_in_accounts" {
  type        = string
  description = "Name of the role in all the accounts that prowler assumes to scan"
}

variable "ecs_cluster_name" {
  description = "Name of cluster"
  type        = string
}

variable "container_name" {
  description = "Name of the Container within AWS Fargate"
  type        = string
}

variable "prowler_container_subnet" {
  type        = string
  description = "Provide a Subnet ID to launch Prowler container"
}

variable "prowler_dashboard_subnet" {
  type        = string
  description = "Provide a Subnet ID to launch Prowler dashboard"
  default     = ""
}

variable "vpc_id" {
  type        = string
  description = "Provide a VPC ID where prowler_container_subnet resides"
}

variable "prowler_report_bucket_name" {
  type        = string
  description = "Name of the bucket where output reports are saved"
}

variable "allowed_ips" {
  description = "ips allowed to access prowler dashboard (add /32 to ips)"
  type        = list(string)
}

variable "prowler_scans" {
  description = "prowler config"
  type = map(object({
    prowler_schedule_timer       = string
    prowler_schedule_timezone    = string
    prowler_scan_regions         = list(string)
    prowler_report_output_format = string
    task_definition_name         = string
    fargate_task_cpu             = string
    fargate_memory               = string
    ecr_image_uri                = string
    prowler_account_list         = list(string)
    compliance_checks            = list(string)
    severity                     = list(string)
  }))
}

variable "report_retention" {
  type        = number
  description = "Number of days to retain prowler reports in bucket"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of kms key for lambda"
}

variable "dlq_arn" {
  type        = string
  description = "ARN for DLQ for lambda"
}

variable "cognito_id_provider_arns" {
  description = "List of arns of cognito identity providers you want to allow to run prowler scans"
  type        = list(any)
}

variable "domain" {
  type        = string
  description = "Domain for dashboard dns record"
}

variable "prowler_ami" {
  type        = string
  description = "AMI id with prowler pre-installed (fast boot time)"
}

variable "dashboard_uptime" {
  description = "Running time of prowler dashboard ec2, will self-terminate after certain amount of time (1d, 1h, 2h, 15m)"
  type        = string
  default     = "1h"
}

variable "mutelist" {
  description = "Contents of the mutelist yaml file"
  type        = string
  default     = "Mutelist: []"
}

variable "dashboard_frontend_url" {
  description = "Frontend page to launch dashboard from"
  type = string
}