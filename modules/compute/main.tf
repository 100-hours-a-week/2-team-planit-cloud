resource "aws_lb" "app" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = var.alb_internal
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  idle_timeout               = var.alb_idle_timeout
  enable_deletion_protection = var.alb_enable_deletion_protection

  tags = {
    Name        = "${var.project}-${var.environment}-alb"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "was" {
  name        = "${var.project}-${var.environment}-was-tg"
  port        = var.was_target_group_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = var.was_target_group_health_check_path
    matcher             = var.target_group_health_check_matcher
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = {
    Name        = "${var.project}-${var.environment}-was-tg"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "ai" {
  name        = "${var.project}-${var.environment}-ai-tg"
  port        = var.ai_target_group_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = var.ai_target_group_health_check_path
    matcher             = var.target_group_health_check_matcher
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = {
    Name        = "${var.project}-${var.environment}-ai-tg"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "chat" {
  name        = "${var.project}-${var.environment}-chat-tg"
  port        = var.chat_target_group_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = var.chat_target_group_health_check_path
    matcher             = var.target_group_health_check_matcher
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = {
    Name        = "${var.project}-${var.environment}-chat-tg"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "chat_path" {
  listener_arn = aws_lb_listener.http.arn
  priority     = var.chat_listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chat.arn
  }

  condition {
    path_pattern {
      values = var.chat_listener_path_patterns
    }
  }
}

resource "aws_lb_listener_rule" "was_path" {
  listener_arn = aws_lb_listener.http.arn
  priority     = var.was_listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.was.arn
  }

  condition {
    path_pattern {
      values = var.was_listener_path_patterns
    }
  }
}

resource "aws_lb_listener_rule" "ai_path" {
  listener_arn = aws_lb_listener.http.arn
  priority     = var.ai_listener_rule_priority

  # NOTE:
  # AWS Console의 URL Rewrite(^/ai/(.*) -> /$1)는 aws_lb_listener_rule의 transform 블록으로
  # 구현 가능하지만, Terraform AWS Provider v6.19.0+가 필요합니다.
  # 현재 프로젝트는 provider "~> 5.0"이므로 path 기반 forward만 우선 반영합니다.
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ai.arn
  }

  condition {
    path_pattern {
      values = var.ai_listener_path_patterns
    }
  }
}

data "aws_cloudfront_cache_policy" "managed_caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "managed_caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "managed_all_viewer" {
  name = "Managed-AllViewer"
}

resource "aws_cloudfront_distribution" "app" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project}-${var.environment}-cloudfront"
  default_root_object = var.cloudfront_default_root_object
  price_class         = var.cloudfront_price_class
  http_version        = var.cloudfront_http_version

  # CloudFront alias는 ACM 인증서(us-east-1)가 있을 때만 활성화
  aliases = var.cloudfront_acm_certificate_arn == null ? [] : var.cloudfront_aliases

  origin {
    domain_name = var.cloudfront_s3_origin_domain_name
    origin_id   = "s3-fe-origin"
    origin_path = var.cloudfront_s3_origin_path

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/${var.cloudfront_oai_id}"
    }
  }

  origin {
    domain_name = aws_lb.app.dns_name
    origin_id   = "alb-app-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "alb-app-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.managed_caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.managed_all_viewer.id
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern           = "/ai/*"
    target_origin_id       = "alb-app-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.managed_caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.managed_all_viewer.id
    compress               = true
  }

  default_cache_behavior {
    target_origin_id       = "s3-fe-origin"
    viewer_protocol_policy = "allow-all"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.managed_caching_optimized.id
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  dynamic "viewer_certificate" {
    for_each = var.cloudfront_acm_certificate_arn == null ? [] : [1]
    content {
      acm_certificate_arn      = var.cloudfront_acm_certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = var.cloudfront_minimum_protocol_version
    }
  }

  dynamic "viewer_certificate" {
    for_each = var.cloudfront_acm_certificate_arn == null ? [1] : []
    content {
      cloudfront_default_certificate = true
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-cloudfront"
    Project     = var.project
    Environment = var.environment
  }
}

data "aws_route53_zone" "public" {
  name         = var.route53_zone_name
  private_zone = false
}

resource "aws_route53_record" "apex_a_v2_cloudfront" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.route53_record_name
  type    = "A"

  set_identifier = var.route53_set_identifier

  weighted_routing_policy {
    weight = var.route53_weight
  }

  alias {
    name                   = aws_cloudfront_distribution.app.domain_name
    zone_id                = aws_cloudfront_distribution.app.hosted_zone_id
    evaluate_target_health = var.route53_evaluate_target_health
  }

  allow_overwrite = true
}

resource "aws_launch_template" "was" {
  name_prefix   = "${var.project}-${var.environment}-was-lt-"
  image_id      = var.was_ami_id
  instance_type = var.was_instance_type
  key_name      = var.was_key_name
  user_data     = var.was_user_data_base64

  vpc_security_group_ids = [var.was_security_group_id]

  dynamic "iam_instance_profile" {
    for_each = var.was_iam_instance_profile_name == null ? [] : [1]
    content {
      name = var.was_iam_instance_profile_name
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.project}-${var.environment}-was"
      Project     = var.project
      Environment = var.environment
      Role        = "was"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name        = "${var.project}-${var.environment}-was-volume"
      Project     = var.project
      Environment = var.environment
      Role        = "was"
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-was-lt"
    Project     = var.project
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "was" {
  name                = "${var.project}-${var.environment}-was-asg"
  min_size            = var.was_asg_min_size
  desired_capacity    = var.was_asg_desired_capacity
  max_size            = var.was_asg_max_size
  vpc_zone_identifier = var.private_app_subnet_ids

  health_check_type         = var.was_health_check_type
  health_check_grace_period = var.was_health_check_grace_period

  launch_template {
    id      = aws_launch_template.was.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-${var.environment}-was"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "was"
    propagate_at_launch = true
  }
}

resource "aws_launch_template" "ai" {
  name_prefix   = "${var.project}-${var.environment}-ai-lt-"
  image_id      = var.ai_ami_id
  instance_type = var.ai_instance_type
  key_name      = var.ai_key_name
  user_data     = var.ai_user_data_base64

  vpc_security_group_ids = [var.ai_security_group_id]

  dynamic "iam_instance_profile" {
    for_each = var.ai_iam_instance_profile_name == null ? [] : [1]
    content {
      name = var.ai_iam_instance_profile_name
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.project}-${var.environment}-ai"
      Project     = var.project
      Environment = var.environment
      Role        = "ai"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name        = "${var.project}-${var.environment}-ai-volume"
      Project     = var.project
      Environment = var.environment
      Role        = "ai"
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-ai-lt"
    Project     = var.project
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ai" {
  name                = "${var.project}-${var.environment}-ai-asg"
  min_size            = var.ai_asg_min_size
  desired_capacity    = var.ai_asg_desired_capacity
  max_size            = var.ai_asg_max_size
  vpc_zone_identifier = var.private_app_subnet_ids

  health_check_type         = var.ai_health_check_type
  health_check_grace_period = var.ai_health_check_grace_period

  launch_template {
    id      = aws_launch_template.ai.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-${var.environment}-ai"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "ai"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "was_tg" {
  autoscaling_group_name = aws_autoscaling_group.was.name
  lb_target_group_arn    = aws_lb_target_group.was.arn
}

resource "aws_autoscaling_attachment" "ai_tg" {
  autoscaling_group_name = aws_autoscaling_group.ai.name
  lb_target_group_arn    = aws_lb_target_group.ai.arn
}

resource "aws_instance" "chat" {
  ami           = var.chat_ami_id
  instance_type = var.chat_instance_type
  subnet_id     = var.chat_subnet_id
  key_name      = var.chat_key_name
  user_data_base64 = var.chat_user_data_base64

  vpc_security_group_ids = [var.chat_security_group_id]
  iam_instance_profile   = var.chat_iam_instance_profile_name

  root_block_device {
    volume_size           = var.chat_root_volume_size_gb
    volume_type           = var.chat_root_volume_type
    encrypted             = var.chat_root_volume_encrypted
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.project}-${var.environment}-chat"
    Project     = var.project
    Environment = var.environment
    Role        = "chat"
  }
}

resource "aws_lb_target_group_attachment" "chat_tg" {
  target_group_arn = aws_lb_target_group.chat.arn
  target_id        = aws_instance.chat.id
  port             = var.chat_target_group_port
}
