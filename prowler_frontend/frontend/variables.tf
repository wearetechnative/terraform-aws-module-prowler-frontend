variable "website_bucket" {
  description = "S3 bucket name for the static website"
  type        = string
}

variable "client_id" {
  description = "Cognito App Client ID"
  type        = string
}

variable "user_pool_domain" {
  description = "Cognito hosted domain (without https://)"
  type        = string
}

variable "api_base" {
  description = "API Gateway base URL"
  type        = string
}