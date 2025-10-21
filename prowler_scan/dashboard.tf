resource "aws_launch_template" "compute" {
  name          = "prowler_dashboard"
  key_name      = module.key_pair.key_pair_name
  image_id      = var.prowler_ami
  instance_type = "t3.small"
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = var.prowler_dashboard_subnet
    security_groups             = [aws_security_group.dashboard_sg.id]
  }
  user_data = base64encode(templatefile("${path.module}/user_data.tftpl", {
    bucket_name = var.prowler_report_bucket_name
  }))
}

data "aws_route53_zone" "this" {
  name = var.domain
}

resource "aws_route53_record" "dashboard" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "dashboard.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.dashboard.dns_name
    zone_id                = aws_lb.dashboard.zone_id
    evaluate_target_health = true
  }
}

module "key_pair" {
  source             = "terraform-aws-modules/key-pair/aws"
  version            = "2.0.2"
  key_name           = "prowler_dashboard"
  create_private_key = true
}

resource "aws_security_group" "dashboard_sg" {
  name        = "Prowler_dashboard_sg"
  description = "Security Group for dashboard"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "inbound_dashboard_ec2" {
  for_each          = toset(var.allowed_ips)
  description       = "Allow dashboard traffic."
  type              = "ingress"
  from_port         = 11666
  to_port           = 11666
  protocol          = "tcp"
  security_group_id = aws_security_group.dashboard_sg.id
  cidr_blocks       = [each.value]
}

resource "aws_security_group_rule" "inbound_ssh_ec2" {
  for_each          = toset(var.allowed_ips)
  description       = "Allow ssh traffic."
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.dashboard_sg.id
  cidr_blocks       = [each.value]
}

resource "aws_security_group_rule" "outbound_dashboard_ec2" {
  description       = "egress allow all."
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.dashboard_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "dashboard_cloudfront" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.dashboard_sg.id
  prefix_list_ids   = [var.prefix_list_id]
}

data "aws_iam_policy_document" "update_trust_relationship" {
  statement {
    sid    = "UpdateTrustRelationship"
    effect = "Allow"
    actions = [
      "ssm:StartSession"
    ]
    resources = [
      "arn:aws:ssm:*:*:document/AWS-StartSSHSession",
    ]
  }
}

data "aws_iam_policy_document" "dashboard_ec2" {
  statement {
    sid    = "jumphostaccess"
    effect = "Allow"
    actions = [
      "ssm:StartSession",
      "ssm:TerminateSession",
    ]
    resources = [
      "arn:aws:ec2:*"
    ]
  }
}

module "ec2_instance_role" {
  source = "git@github.com:wearetechnative/terraform-aws-iam-role?ref=0fe916c27097706237692122e09f323f55e8237e"

  role_name = "ec2_instance_role"
  role_path = "/network/"

  aws_managed_policies = ["AmazonSSMManagedInstanceCore"]
  customer_managed_policies = {
    "s3_access" : jsondecode(data.aws_iam_policy_document.s3_access.json)
  }

  trust_relationship = {
    "ec2" : { "identifier" : "ec2.amazonaws.com", "identifier_type" : "Service", "enforce_mfa" : false, "enforce_userprincipal" : false, "external_id" : null, "prevent_account_confuseddeputy" : false }
  }
}


data "aws_iam_policy_document" "s3_access" {
  statement {

    sid = "S3ListBuckets"

    actions = ["s3:ListAllMyBuckets"]

    resources = [
      "arn:aws:s3:::*",
    ]
  }

  statement {
    sid = "S3ReportAccess"

    actions = [
      "s3:GetObject",
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]

    resources = [
      "${aws_s3_bucket.prowler_bucket.arn}",
      "${aws_s3_bucket.prowler_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_dashboard_profile"
  role = module.ec2_instance_role.role_name
}


resource "aws_iam_role_policy" "update_trust_relationship" {
  name   = "UpdateTrustRelationship"
  role   = module.ec2_instance_role.role_name
  policy = data.aws_iam_policy_document.update_trust_relationship.json
}

resource "aws_iam_policy" "dashboard_ec2" {
  name        = "dashboard_instance_policy"
  description = "Policy jumphost access role"
  policy      = data.aws_iam_policy_document.dashboard_ec2.json
}

resource "aws_iam_role_policy_attachment" "dashboard_ec2" {
  role       = module.ec2_instance_role.role_name
  policy_arn = aws_iam_policy.dashboard_ec2.arn
}