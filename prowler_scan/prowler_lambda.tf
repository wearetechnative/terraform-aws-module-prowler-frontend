module "lambda_prowler" {
  source = "git::https://github.com/wearetechnative/terraform-aws-lambda.git?ref=b9da56ded8f437adde4fe9819fb292050c7ee515"


  name              = "prowler_task_execution_lamdba"
  role_arn          = module.iam_role_lambda_prowler.role_arn
  role_arn_provided = true
  kms_key_arn       = var.kms_key_arn

  handler     = "lambda_function.lambda_handler"
  memory_size = 128
  timeout     = 600
  runtime     = "python3.13"

  source_type               = "local"
  source_directory_location = "${path.module}/prowler_lambda/"
  source_file_name          = null

  environment_variables = {
    CLUSTER                   = var.ecs_cluster_name
    SUBNET                    = var.prowler_container_subnet
    DASHBOARD_LAUNCH_TEMPLATE = aws_launch_template.compute.name
    DASHBOARD_UPTIME          = var.dashboard_uptime
    DASHBOARD_TG_ARN          = aws_lb_target_group.dashboard.arn
    DASHBOARD_ALB_DNS         = aws_lb.dashboard.dns_name
  }

  sqs_dlq_arn = var.dlq_arn
}

module "iam_role_lambda_prowler" {
  source = "git::https://github.com/wearetechnative/terraform-aws-iam-role.git?ref=377cfce5febad930cb61097cd61c5a3f3f8925fd"

  role_name = "prowler_lambda_role"
  role_path = "/"

  customer_managed_policies = {
    "lambda_run_task" : jsondecode(data.aws_iam_policy_document.lambda_run_task.json)
    "lambda_list_tasks" : jsondecode(data.aws_iam_policy_document.lambda_list_tasks.json)
    "lambda_pass_role" : jsondecode(data.aws_iam_policy_document.lambda_pass_role.json)
    "lambda_launch_dashboard" : jsondecode(data.aws_iam_policy_document.launch_dashboard.json)
  }

  trust_relationship = {
    "lambda" : { "identifier" : "lambda.amazonaws.com", "identifier_type" : "Service", "enforce_mfa" : false, "enforce_userprincipal" : false, "external_id" : null, "prevent_account_confuseddeputy" : false }
  }
}

data "aws_iam_policy_document" "launch_dashboard" {
  statement {
    sid = "EC2LaunchFromTemplate"
    actions = [
      "ec2:RunInstances",
      "ec2:DescribeInstances",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:CreateTags",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeTags",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeTargetHealth"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "lambda_run_task" {
  statement {
    sid = "AllowLambdaRunTask"

    actions = ["ecs:RunTask"]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "lambda_list_tasks" {
  statement {
    sid = "AllowLambdaListTaskdefs"

    actions = ["ecs:ListTaskDefinitions"]

    resources = ["*"]
  }
  statement {
    sid       = "DescribeTasks"
    actions   = ["ecs:DescribeTasks"]
    resources = ["*"]
  }
  statement {
    sid       = "ListTasks"
    actions   = ["ecs:ListTasks"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "lambda_pass_role" {
  statement {
    sid = "AllowLambdaListTasks"

    actions = ["iam:PassRole"]

    resources = [aws_iam_role.executionrole.arn, aws_iam_role.taskrole.arn, module.ec2_instance_role.role_arn]
  }
}

resource "aws_lambda_permission" "allow_all_apigateway_calls" {
  statement_id  = "AllowAllMethodsFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_prowler.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.prowler.execution_arn}/*/*"
}