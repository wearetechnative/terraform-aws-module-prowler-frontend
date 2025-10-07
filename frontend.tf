module "prowler_frontend" {
    source = "./frontend"
    website_bucket = module.website_bucket.s3_bucket_id
    client_id = module.cognito-user-pool.client_ids
    user_pool_domain = "login.${domain}"
    api_base = var.api_gateway_stage_invoke_url

}