terraform {
  required_version = ">= 1.0.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.9.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.2.0, < 3.0.0"
    }
  }
}

locals {
  base_path         = "${path.module}/../../external/cloudfront-authorization-at-edge/${var.function}"
  path_configuration = "${local.base_path}/configuration.json"
}

resource "local_file" "function_configuration" {
  filename = local.path_configuration
  content  = jsonencode(var.configuration)
}

data "archive_file" "archive" {
  type        = "zip"
  source_dir  = local.base_path
  output_path = "${local.base_path}-v1.zip"
  output_file_mode = "0666"

  depends_on = [
    local_file.function_configuration,
  ]
}

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.0.1"

  function_name = "${var.name}-${var.function}"
  handler       = "bundle.handler"
  runtime       = "nodejs22.x"

  publish        = true
  lambda_at_edge = true

  create_package         = false
  local_existing_package = data.archive_file.archive.output_path

  tracing_mode = "Active"

  depends_on = [
    local_file.function_configuration,
  ]
}
