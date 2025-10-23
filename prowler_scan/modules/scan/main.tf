resource "aws_ecs_task_definition" "prowler_ecs_task_definition" {
  for_each                 = toset(var.prowler_account_list)
  family                   = "${var.task_definition_name}-${var.scan_name}-${each.value}"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.fargate_task_cpu
  memory                   = var.fargate_memory

  container_definitions = jsonencode(
    [
      {
        command = concat([
          "aws",
          "-R",
          "arn:aws:iam::${each.value}:role/${var.prowler_rolename_in_accounts}",
          "-M",
          "${var.prowler_report_output_format}",
          "-D",
          "${var.prowler_bucket_id}",
          "-w",
          "s3://${var.prowler_bucket_id}/mutelist/mutelist.yaml"],
        local.command_args)


        essential = true
        image     = "${var.ecr_image_uri}"
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-create-group  = "true"
            awslogs-group         = "/ecs/${var.container_name}"
            awslogs-region        = "${var.region}"
            awslogs-stream-prefix = "ecs"
            max-buffer-size       = "25m"
            mode                  = "non-blocking"
          }
          secretOptions = []
        }
        name = "${var.container_name}"
      }
    ]
  )
}


resource "aws_scheduler_schedule" "prowler" {
  for_each   = toset(var.prowler_account_list)
  name       = "${var.container_name}-${var.scan_name}-${each.value}"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression_timezone = var.prowler_schedule_timezone
  schedule_expression          = var.prowler_schedule_timer

  target {
    arn      = var.prowler_ecs_cluster_arn
    role_arn = var.schedule_role_arn

    ecs_parameters {
      launch_type            = "FARGATE"
      task_definition_arn    = aws_ecs_task_definition.prowler_ecs_task_definition[each.key].arn
      task_count             = "1"
      platform_version       = "1.4.0"
      enable_execute_command = true
      network_configuration {
        security_groups  = [var.prowler_sg]
        subnets          = [var.prowler_container_subnet]
        assign_public_ip = true
      }
    }
  }
}