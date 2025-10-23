output "taskdef_arns" {
  value = [for taskdef in aws_ecs_task_definition.prowler_ecs_task_definition : taskdef.arn]
}