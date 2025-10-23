resource "aws_s3_bucket" "prowler_bucket" {
  bucket = var.prowler_report_bucket_name
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.prowler_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.prowler_bucket.id
  rule {
    id = "retention"
    filter {
      prefix = "output/"
    }
    expiration {
      days = var.report_retention
    }
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.prowler_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "mutelist" {
  key     = "mutelist/mutelist.yaml"
  bucket  = aws_s3_bucket.prowler_bucket.id
  content = var.mutelist
}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
  for_each = data.aws_iam_policy_document.allow_getobject_from_other_accounts
  bucket   = aws_s3_bucket.prowler_bucket.id
  policy   = data.aws_iam_policy_document.allow_getobject_from_other_accounts[each.key].json
}

data "aws_iam_policy_document" "allow_getobject_from_other_accounts" {
  for_each = var.prowler_scans
  statement {
    principals {
      type        = "AWS"
      identifiers = each.value.prowler_account_list
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.prowler_bucket.arn}/mutelist/*",
    ]
  }
}