locals {
  scan_html = templatefile("${path.module}/templates/scan.html.tmpl", {
    CLIENT_ID        = var.client_id
    USER_POOL_DOMAIN = var.user_pool_domain
    APIBase         = var.api_base
  })

  dashboard_html = templatefile("${path.module}/templates/dashboard.html.tmpl", {
    CLIENT_ID        = var.client_id
    USER_POOL_DOMAIN = var.user_pool_domain
    APIBase         = var.api_base
  })
}

resource "aws_s3_object" "scan_page" {
  bucket       = var.website_bucket
  key          = "index.html"
  content      = local.scan_html
  content_type = "text/html"
  etag         = md5(local.scan_html)
}

resource "aws_s3_object" "dashboard_page" {
  bucket       = var.website_bucket
  key          = "dashboard.html"
  content      = local.dashboard_html
  content_type = "text/html"
  etag         = md5(local.dashboard_html)
}