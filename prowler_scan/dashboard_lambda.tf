module "lambda_terminate_dashboard" {
  source = "git@github.com:wearetechnative/terraform-aws-lambda.git?ref=13eda5f9e8ae40e51f66a45837cd41a6b35af988"

  name              = "stop_dashboard_lamdba"
  role_arn          = module.iam_role_lambda_terminate_dashboard.role_arn
  role_arn_provided = true
  kms_key_arn       = var.kms_key_arn

  handler     = "lambda_function.lambda_handler"
  memory_size = 128
  timeout     = 600
  runtime     = "python3.13"

  source_type               = "local"
  source_directory_location = "${path.module}/dashboard_lambda/"
  source_file_name          = null

  environment_variables = {
    TARGET_GROUP_ARN = aws_lb_target_group.dashboard.arn
  }

  sqs_dlq_arn = var.dlq_arn
}

module "iam_role_lambda_terminate_dashboard" {

  source = "git@github.com:wearetechnative/terraform-aws-iam-role.git?ref=9229bbd0280807cbc49f194ff6d2741265dc108a"

  role_name = "dashboard_lambda_role"
  role_path = "/"

  customer_managed_policies = {
    "terminate_dashboard" : jsondecode(data.aws_iam_policy_document.terminate_dashboard.json)
  }

  trust_relationship = {
    "lambda" : { "identifier" : "lambda.amazonaws.com", "identifier_type" : "Service", "enforce_mfa" : false, "enforce_userprincipal" : false, "external_id" : null, "prevent_account_confuseddeputy" : false }
  }
}

data "aws_iam_policy_document" "terminate_dashboard" {
  statement {
    sid = "EC2AccessForTermination"
    actions = [
      "ec2:RunInstances",
      "ec2:DescribeInstances",
      "ec2:TerminateInstances",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTargetGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_cloudwatch_event_rule" "terminate_schedule" {
  name                = "terminate-dashboard-ec2-schedule"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.terminate_schedule.name
  target_id = "TerminateEC2Instances"
  arn       = module.lambda_terminate_dashboard.lambda_function_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_terminate_dashboard.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.terminate_schedule.arn
}
