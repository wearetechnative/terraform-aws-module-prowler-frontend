resource "aws_api_gateway_rest_api" "prowler" {
  name        = "Prowler"
  description = "API Gateway for launching prowler tasks"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_authorizer" "prowler" {
  name            = "prowler_scan_auth"
  rest_api_id     = local.rest_api_id
  type            = "COGNITO_USER_POOLS"
  identity_source = "method.request.header.Authorization"
  provider_arns   = var.cognito_id_provider_arns
}

module "api_endpoints" {
  source = "./modules/api_gateway"

  for_each = local.endpoints

  rest_api_id       = local.rest_api_id
  parent_id         = local.parent_id
  path_part         = each.key
  http_method       = each.value.http_method
  authorizer_id     = aws_api_gateway_authorizer.prowler.id
  lambda_invoke_arn = module.lambda_prowler.lambda_function_invoke_arn

  cors_headers    = local.cors_headers
  cors_origin     = local.cors_origin
  allowed_methods = each.value.allowed_methods
}

resource "aws_api_gateway_deployment" "prowler" {
  rest_api_id = local.rest_api_id
  triggers = {
    redeploy = timestamp()
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    module.api_endpoints
  ]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.prowler.id
  rest_api_id   = local.rest_api_id
  stage_name    = "prod"
}

resource "null_resource" "stage_blocker" {
  triggers = {
    always_run = timestamp()
  }

  depends_on = [aws_api_gateway_stage.prod]
}