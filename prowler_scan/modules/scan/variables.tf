variable "region" {
  description = "Region to deploy the resources."
  type        = string
}

variable "prowler_schedule_timezone" {
  type        = string
  description = "Timezone for the scheduler"
  default     = "UTC"
}

variable "prowler_schedule_timer" {
  type        = string
  description = "Expression for the timer of the prowler schedule"
  default     = "rate(24 hours)"
}

variable "prowler_scan_regions" {
  type        = list(string)
  description = "Region for prowler to scan in the accounts"
}

variable "prowler_report_output_format" {
  type        = string
  description = "Can either be csv, html and json or any combination seperated by a space: 'html csv json'"
}

variable "prowler_rolename_in_accounts" {
  type        = string
  description = "Name of the role in all the accounts that prowler assumes to scan"
}

variable "ecs_cluster_name" {
  description = "Name of cluster"
  type        = string
}

variable "task_definition_name" {
  description = "Name of task definition."
  type        = string
}

variable "fargate_task_cpu" {
  type        = string
  default     = "512"
  description = "CPU for AWS Fargate Task"
}

variable "fargate_memory" {
  type        = string
  default     = "1024"
  description = "Memory Reservation for AWS Fargate Task"
}

variable "container_name" {
  description = "Name of the Container within AWS Fargate"
  type        = string
}

variable "ecr_image_uri" {
  type        = string
  description = "URI Path of the Prowler Docker Image - Preferably from ECR"
}

variable "prowler_container_subnet" {
  type        = string
  description = "Provide a Subnet ID to launch Prowler container"
}

variable "vpc_id" {
  type        = string
  description = "Provide a VPC ID where prowler_container_subnet resides"
}

variable "prowler_account_list" {
  type        = list(string)
  description = "List of account id's to scan with prowler"
}

variable "prowler_report_bucket_name" {
  type        = string
  description = "Name of the bucket where output reports are saved"
}
variable "task_role_id" {
  type = string
}
variable "schedule_role_id" {
  type = string
}
variable "execution_role_arn" {
  type = string
}
variable "task_role_arn" {
  type = string
}
variable "schedule_role_arn" {
  type = string
}
variable "prowler_bucket_id" {
  type = string
}
variable "prowler_ecs_cluster_arn" {
  type = string
}
variable "prowler_sg" {
  type = string
}
variable "compliance_checks" {
  type    = list(string)
  default = []
}

variable "severity" {
  type    = list(string)
  default = []
}

variable "scan_name" {
  type = string
}