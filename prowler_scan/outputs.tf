output "bucket_arn" {
  value = aws_s3_bucket.prowler_bucket.arn
}

output "api_gateway_stage_invoke_url" {
  value = "https://${aws_api_gateway_rest_api.prowler.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}"
}
