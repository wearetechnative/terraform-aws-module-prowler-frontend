locals {
  base_path          = "${path.module}/../../external/cloudfront-authorization-at-edge/${var.function}"
  build_dir          = "${path.root}/.terraform-build"
  zip_output_path    = "${local.build_dir}/${var.function}-v1.zip"
  path_configuration = "${local.base_path}/configuration.json"
}

resource "null_resource" "prepare_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.build_dir}"
  }
}

resource "local_file" "function_configuration" {
  filename = local.path_configuration
  content  = jsonencode(var.configuration)
}

data "archive_file" "archive" {
  type             = "zip"
  source_dir       = local.base_path
  output_path      = local.zip_output_path
  output_file_mode = "0666"

  depends_on = [
    local_file.function_configuration,
    null_resource.prepare_build_dir,
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
  local_existing_package = abspath(local.zip_output_path)

  tracing_mode = "Active"

  depends_on = [
    data.archive_file.archive,
    local_file.function_configuration,
  ]
}
