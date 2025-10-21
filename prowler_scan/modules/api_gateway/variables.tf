variable "rest_api_id" {
  description = "ID of the REST API"
  type        = string
}

variable "parent_id" {
  description = "Parent resource ID"
  type        = string
}

variable "path_part" {
  description = "Path part for the resource"
  type        = string
}

variable "http_method" {
  description = "HTTP method (GET, POST, etc.)"
  type        = string
}

variable "authorizer_id" {
  description = "ID of the authorizer"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "ARN of the Lambda function to invoke"
  type        = string
}

variable "cors_headers" {
  description = "CORS allowed headers"
  type        = string
}

variable "cors_origin" {
  description = "CORS allowed origin"
  type        = string
}

variable "allowed_methods" {
  description = "CORS allowed methods"
  type        = string
}