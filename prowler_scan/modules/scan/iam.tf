resource "aws_iam_role_policy" "allow_assumerole" {
  for_each = toset(var.prowler_account_list)
  name     = "assume_role_prowler-${var.scan_name}-${each.value}"
  role     = var.task_role_id


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::${each.value}:role/${var.prowler_rolename_in_accounts}"
      }
    ]
  })
}
resource "aws_iam_role_policy" "allow_runtask_schedule" {
  for_each = toset(var.prowler_account_list)
  name     = "prowler_schedule_runtask_policy_${var.scan_name}_${each.key}"
  role     = var.schedule_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecs:RunTask"
        Resource = aws_ecs_task_definition.prowler_ecs_task_definition[each.key].arn
      }
    ]
  })
}