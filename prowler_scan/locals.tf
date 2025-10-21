locals {

  prowler_scan = { for k, value in flatten([
    for prowler_key, prowler_value in var.prowler_scans : {
      prowler_scan                 = prowler_key
      prowler_schedule_timer       = prowler_value.prowler_schedule_timer
      prowler_schedule_timezone    = prowler_value.prowler_schedule_timezone
      prowler_scan_regions         = prowler_value.prowler_scan_regions
      prowler_report_output_format = prowler_value.prowler_report_output_format
      task_definition_name         = prowler_value.task_definition_name
      fargate_task_cpu             = prowler_value.fargate_task_cpu
      fargate_memory               = prowler_value.fargate_memory
      ecr_image_uri                = prowler_value.ecr_image_uri
      prowler_account_list         = prowler_value.prowler_account_list
    }
  ]) : "${value.prowler_scan}" => value }

  rest_api_id = aws_api_gateway_rest_api.prowler.id
  parent_id   = aws_api_gateway_rest_api.prowler.root_resource_id

  cors_headers = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
  cors_origin  = "'*'"

  endpoints = {
    "start-task" = {
      http_method     = "POST",
      allowed_methods = "'POST,OPTIONS'"
    },
    "check-task-status" = {
      http_method     = "GET",
      allowed_methods = "'GET,OPTIONS'"
    },
    "launch-dashboard" = {
      http_method     = "POST",
      allowed_methods = "'POST,OPTIONS'"
    },
    "check-dashboard-status" = {
      http_method     = "GET",
      allowed_methods = "'GET,OPTIONS'"
    }
  }
}