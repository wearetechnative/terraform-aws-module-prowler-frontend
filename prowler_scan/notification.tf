resource "aws_cloudwatch_event_rule" "failed_task" {
  name        = "prowler-task-failure"
  description = "Catch ECS tasks that stop"
  event_pattern = jsonencode({
    source      = ["aws.ecs"],
    detail-type = ["ECS Task State Change"],
    detail = {
      lastStatus = ["STOPPED"]
      containers = {
        name = ["prowler-task"]
      }
    }
  })
}

module "lambda_prowler_failed_task" {
  source = "git@github.com:wearetechnative/terraform-aws-lambda.git?ref=13eda5f9e8ae40e51f66a45837cd41a6b35af988"


  name              = "check_failed_task_lamdba"
  role_arn          = module.iam_role_lambda_prowler_failed_task.role_arn
  role_arn_provided = true
  kms_key_arn       = var.kms_key_arn

  handler     = "lambda_function.lambda_handler"
  memory_size = 128
  timeout     = 600
  runtime     = "python3.13"

  source_type               = "local"
  source_directory_location = "${path.module}/failed_task_lambda/"
  source_file_name          = null

  environment_variables = {
<<<<<<< HEAD
    TOPICARN     = aws_sns_topic.check_fail.arn
=======
    TOPICARN = aws_sns_topic.check_fail.arn
>>>>>>> main
    FRONTEND_URL = var.dashboard_frontend_url
  }

  sqs_dlq_arn = var.dlq_arn
}

resource "aws_cloudwatch_event_target" "failed_task" {
  rule      = aws_cloudwatch_event_rule.failed_task.name
  target_id = "NotifyOnFailedCheck"
  arn       = module.lambda_prowler_failed_task.lambda_function_arn
}

resource "aws_lambda_permission" "failed_task" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_prowler_failed_task.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.failed_task.arn
}

module "iam_role_lambda_prowler_failed_task" {
  source = "git@github.com:wearetechnative/terraform-aws-iam-role.git?ref=9229bbd0280807cbc49f194ff6d2741265dc108a"

  role_name = "failed_task_lambda_role"
  role_path = "/"

  customer_managed_policies = {
    "publish_failed_task" : jsondecode(data.aws_iam_policy_document.publish_failed_task.json)
  }

  trust_relationship = {
    "lambda" : { "identifier" : "lambda.amazonaws.com", "identifier_type" : "Service", "enforce_mfa" : false, "enforce_userprincipal" : false, "external_id" : null, "prevent_account_confuseddeputy" : false }
  }
}

data "aws_iam_policy_document" "publish_failed_task" {
  statement {
    sid = "PublishToSNS"
    actions = [
      "sns:Publish"
    ]
    resources = ["*"]
  }
}

resource "aws_sns_topic" "check_fail" {
  name = "prowler_security_check_fail_notifier"
}

resource "aws_sns_topic_policy" "check_fail" {
  arn    = aws_sns_topic.check_fail.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.check_fail.arn]
  }
}
