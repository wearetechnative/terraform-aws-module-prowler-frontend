module "prowler" {
  for_each                     = var.prowler_scans
  source                       = "./modules/scan"
  scan_name                    = each.key
  prowler_schedule_timer       = each.value.prowler_schedule_timer
  prowler_schedule_timezone    = each.value.prowler_schedule_timezone
  prowler_scan_regions         = each.value.prowler_scan_regions
  prowler_report_output_format = each.value.prowler_report_output_format
  task_definition_name         = each.value.task_definition_name
  fargate_task_cpu             = each.value.fargate_task_cpu
  fargate_memory               = each.value.fargate_memory
  ecr_image_uri                = each.value.ecr_image_uri
  prowler_account_list         = each.value.prowler_account_list
  compliance_checks            = each.value.compliance_checks
  severity                     = each.value.severity

  ecs_cluster_name             = var.ecs_cluster_name
  container_name               = var.container_name
  prowler_rolename_in_accounts = var.prowler_rolename_in_accounts
  prowler_container_subnet     = var.prowler_container_subnet
  vpc_id                       = var.vpc_id
  prowler_report_bucket_name   = var.prowler_report_bucket_name
  region                       = var.region
  task_role_id                 = aws_iam_role.taskrole.id
  schedule_role_id             = aws_iam_role.schedulerole.id
  execution_role_arn           = aws_iam_role.executionrole.arn
  schedule_role_arn            = aws_iam_role.schedulerole.arn
  task_role_arn                = aws_iam_role.taskrole.arn
  prowler_bucket_id            = aws_s3_bucket.prowler_bucket.id
  prowler_ecs_cluster_arn      = aws_ecs_cluster.prowler_ecs_cluster.arn
  prowler_sg                   = aws_security_group.prowler.id
}

resource "aws_ecs_cluster" "prowler_ecs_cluster" {
  name = var.ecs_cluster_name
}

resource "aws_security_group" "prowler" {
  name   = "prowler_sg"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "prowler_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.prowler.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_cloudwatch_log_group" "prowler_cw_log_group" {
  name              = "/ecs/${var.container_name}"
  retention_in_days = "30"
}



