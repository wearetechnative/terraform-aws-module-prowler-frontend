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
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb" "dashboard" {
  name               = "prowler-dashboard-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.public.ids
}

resource "aws_security_group" "alb_sg" {
  name   = "dashboard-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    prefix_list_ids   = [var.prefix_list_id] # or CloudFront prefix list for better security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_listener" "dashboard_http" {
  load_balancer_arn = aws_lb.dashboard.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dashboard.arn
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

resource "aws_security_group_rule" "allow_cloudfront_to_alb" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  prefix_list_ids   = [data.aws_prefix_list.cloudfront.id]
}

resource "aws_lb_listener_rule" "allow_cloudfront_header" {
  listener_arn = aws_lb_listener.dashboard_http.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dashboard.arn
  }

  condition {
    http_header {
      http_header_name = "X-CloudFront-Secret"
      values           = [var.cloudfront_secret]
    }
  }
}

# Default action blocks everything else
resource "aws_lb_listener_rule" "deny_all" {
  listener_arn = aws_lb_listener.dashboard_http.arn
  priority     = 99

  action {
    type = "fixed-response"
    fixed_response {
      status_code  = "403"
      content_type = "text/plain"
      message_body = "Forbidden"
    }
  }
  condition {
    path_pattern {
      values = ["*"]
    }
  }
}