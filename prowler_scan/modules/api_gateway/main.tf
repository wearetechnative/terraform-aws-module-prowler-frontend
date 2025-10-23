resource "aws_api_gateway_resource" "endpoint" {
  rest_api_id = var.rest_api_id
  parent_id   = var.parent_id
  path_part   = var.path_part
}

resource "aws_api_gateway_method" "endpoint" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.endpoint.id
  http_method   = var.http_method
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = var.authorizer_id
}

resource "aws_api_gateway_integration" "endpoint" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.endpoint.id
  http_method             = aws_api_gateway_method.endpoint.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

resource "aws_api_gateway_method_response" "endpoint" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.endpoint.id
  http_method = aws_api_gateway_method.endpoint.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "endpoint" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.endpoint.id
  http_method = aws_api_gateway_method.endpoint.http_method
  status_code = aws_api_gateway_method_response.endpoint.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = var.cors_origin
    "method.response.header.Access-Control-Allow-Headers" = var.cors_headers
    "method.response.header.Access-Control-Allow-Methods" = var.allowed_methods
  }

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_method" "options" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.endpoint.id
  http_method   = "OPTIONS"
  authorization = "NONE"

  request_parameters = {
    "method.request.header.Origin"                         = false
    "method.request.header.Access-Control-Request-Method"  = false
    "method.request.header.Access-Control-Request-Headers" = false
  }
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.endpoint.id
  http_method = aws_api_gateway_method.options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.endpoint.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.endpoint.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = aws_api_gateway_method_response.options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = var.cors_headers
    "method.response.header.Access-Control-Allow-Methods" = var.allowed_methods
    "method.response.header.Access-Control-Allow-Origin"  = var.cors_origin
  }

  response_templates = {
    "application/json" = ""
  }
}