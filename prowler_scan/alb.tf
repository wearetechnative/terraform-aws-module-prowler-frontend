resource "aws_lb_target_group" "dashboard" {
  name        = "prowler-dashboard-tg"
  port        = 11666
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    port                = "11666"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 4
  }
}

resource "aws_lb" "dashboard" {
  name               = "prowler-dashboard-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.public.ids
}

data "aws_route53_zone" "prowler" {
  name = var.domain
}

resource "aws_route53_record" "dashboard" {
  zone_id = data.aws_route53_zone.prowler.zone_id
  name    = "dashboard.prowler.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.dashboard.dns_name
    zone_id                = aws_lb.dashboard.zone_id
    evaluate_target_health = true
  }
}

resource "aws_security_group" "alb_sg" {
  name   = "dashboard-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.0.0"

  domain_name               = var.domain
  subject_alternative_names = ["*.prowler.${var.domain}"]
  zone_id                   = data.aws_route53_zone.prowler.id
  validation_method         = "DNS"
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.dashboard.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = module.acm.acm_certificate_arn
  default_action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn       = var.cognito_id_provider_arns[0]
      user_pool_client_id = var.dashboard_client_id
      user_pool_domain    = var.cognito_domain
    }
    order = 1
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dashboard.arn
    order            = 2
  }
}

resource "aws_security_group_rule" "alb_to_dashboard" {
  type                     = "ingress"
  from_port                = 11666
  to_port                  = 11666
  protocol                 = "tcp"
  security_group_id        = aws_security_group.dashboard_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}
