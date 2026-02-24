locals {
  sg_names = {
    alb   = "planit-v2-alb-sg"
    ai    = "planit-v2-ai-sg"
    be    = "planit-v2-be-sg"
    db    = "planit-v2-db-sg"
    queue = "planit-v2-queue-sg"
    nat   = "planit-nat-sg"
  }

  cloudfront_prefix_list_id = "pl-22a6434b"

  ingress_rules = {
    alb_https_from_be = {
      sg          = "alb"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      source_sg   = "be"
      description = "HTTPS from be_sg"
    }
    alb_http_from_cloudfront = {
      sg             = "alb"
      protocol       = "tcp"
      from_port      = 80
      to_port        = 80
      prefix_list_id = local.cloudfront_prefix_list_id
      description    = "HTTP from CloudFront"
    }
    alb_https_from_nat = {
      sg          = "alb"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      source_sg   = "nat"
      description = "HTTPS from nat_sg"
    }
    alb_http_from_nat = {
      sg          = "alb"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      source_sg   = "nat"
      description = "HTTP from nat_sg"
    }
    alb_https_from_cloudfront = {
      sg             = "alb"
      protocol       = "tcp"
      from_port      = 443
      to_port        = 443
      prefix_list_id = local.cloudfront_prefix_list_id
      description    = "HTTPS from CloudFront"
    }
    alb_http_from_ai = {
      sg          = "alb"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      source_sg   = "ai"
      description = "HTTP from ai_sg"
    }
    alb_http_from_be = {
      sg          = "alb"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      source_sg   = "be"
      description = "HTTP from be_sg"
    }

    ai_8000_from_be = {
      sg          = "ai"
      protocol    = "tcp"
      from_port   = 8000
      to_port     = 8000
      source_sg   = "be"
      description = "App traffic from be_sg"
    }
    ai_8000_from_alb = {
      sg          = "ai"
      protocol    = "tcp"
      from_port   = 8000
      to_port     = 8000
      source_sg   = "alb"
      description = "App traffic from alb_sg"
    }

    be_8080_from_alb = {
      sg          = "be"
      protocol    = "tcp"
      from_port   = 8080
      to_port     = 8080
      source_sg   = "alb"
      description = "App traffic from alb_sg"
    }
    be_8081_from_alb = {
      sg          = "be"
      protocol    = "tcp"
      from_port   = 8081
      to_port     = 8081
      source_sg   = "alb"
      description = "App traffic alt from alb_sg"
    }

    db_27017_from_ai = {
      sg          = "db"
      protocol    = "tcp"
      from_port   = 27017
      to_port     = 27017
      source_sg   = "ai"
      description = "MongoDB from ai_sg"
    }
    db_3306_from_be = {
      sg          = "db"
      protocol    = "tcp"
      from_port   = 3306
      to_port     = 3306
      source_sg   = "be"
      description = "MySQL from be_sg"
    }
    db_3306_from_ai = {
      sg          = "db"
      protocol    = "tcp"
      from_port   = 3306
      to_port     = 3306
      source_sg   = "ai"
      description = "MySQL from ai_sg"
    }
    db_27017_from_be = {
      sg          = "db"
      protocol    = "tcp"
      from_port   = 27017
      to_port     = 27017
      source_sg   = "be"
      description = "MongoDB from be_sg"
    }

    queue_6379_from_be = {
      sg          = "queue"
      protocol    = "tcp"
      from_port   = 6379
      to_port     = 6379
      source_sg   = "be"
      description = "Redis from be_sg"
    }

    nat_443_from_10_0_21 = {
      sg          = "nat"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "10.0.21.0/24"
      description = "HTTPS from 10.0.21.0/24"
    }
    nat_80_from_10_0_20 = {
      sg          = "nat"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = "10.0.20.0/24"
      description = "HTTP from 10.0.20.0/24"
    }
    nat_80_from_10_0_21 = {
      sg          = "nat"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = "10.0.21.0/24"
      description = "HTTP from 10.0.21.0/24"
    }
    nat_443_from_10_0_11 = {
      sg          = "nat"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "10.0.11.0/24"
      description = "HTTPS from 10.0.11.0/24"
    }
    nat_80_from_10_0_11 = {
      sg          = "nat"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = "10.0.11.0/24"
      description = "HTTP from 10.0.11.0/24"
    }
    nat_443_from_10_0_10 = {
      sg          = "nat"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "10.0.10.0/24"
      description = "HTTPS from 10.0.10.0/24"
    }
    nat_80_from_10_0_10 = {
      sg          = "nat"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = "10.0.10.0/24"
      description = "HTTP from 10.0.10.0/24"
    }
    nat_443_from_10_0_20 = {
      sg          = "nat"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "10.0.20.0/24"
      description = "HTTPS from 10.0.20.0/24"
    }

  }

  egress_rules = {
    alb_8080_to_be = {
      sg          = "alb"
      protocol    = "tcp"
      from_port   = 8080
      to_port     = 8080
      target_sg   = "be"
      description = "HTTP to be_sg"
    }
    alb_8000_to_ai = {
      sg          = "alb"
      protocol    = "tcp"
      from_port   = 8000
      to_port     = 8000
      target_sg   = "ai"
      description = "HTTP to ai_sg"
    }
    alb_8081_to_be = {
      sg          = "alb"
      protocol    = "tcp"
      from_port   = 8081
      to_port     = 8081
      target_sg   = "be"
      description = "HTTP-alt to be_sg"
    }

    ai_3306_to_db = {
      sg          = "ai"
      protocol    = "tcp"
      from_port   = 3306
      to_port     = 3306
      target_sg   = "db"
      description = "MySQL to db_sg"
    }
    ai_27017_to_db = {
      sg          = "ai"
      protocol    = "tcp"
      from_port   = 27017
      to_port     = 27017
      target_sg   = "db"
      description = "MongoDB to db_sg"
    }
    ai_443_to_anywhere = {
      sg          = "ai"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTPS outbound"
    }

    be_3306_to_db = {
      sg          = "be"
      protocol    = "tcp"
      from_port   = 3306
      to_port     = 3306
      target_sg   = "db"
      description = "MySQL to db_sg"
    }
    be_27017_to_db = {
      sg          = "be"
      protocol    = "tcp"
      from_port   = 27017
      to_port     = 27017
      target_sg   = "db"
      description = "MongoDB to db_sg"
    }
    be_6379_to_queue = {
      sg          = "be"
      protocol    = "tcp"
      from_port   = 6379
      to_port     = 6379
      target_sg   = "queue"
      description = "Redis to queue_sg"
    }
    be_443_to_anywhere = {
      sg          = "be"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTPS outbound"
    }

    db_80_to_anywhere = {
      sg          = "db"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTP outbound"
    }
    db_3306_to_anywhere = {
      sg          = "db"
      protocol    = "tcp"
      from_port   = 3306
      to_port     = 3306
      cidr_ipv4   = "0.0.0.0/0"
      description = "MySQL outbound"
    }
    db_3307_to_anywhere = {
      sg          = "db"
      protocol    = "tcp"
      from_port   = 3307
      to_port     = 3307
      cidr_ipv4   = "0.0.0.0/0"
      description = "MySQL alt outbound"
    }
    db_443_to_anywhere = {
      sg          = "db"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTPS outbound"
    }

    queue_all_to_anywhere = {
      sg          = "queue"
      protocol    = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "All outbound"
    }

    nat_all_to_anywhere = {
      sg          = "nat"
      protocol    = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "All outbound"
    }
    nat_80_to_anywhere = {
      sg          = "nat"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTP outbound"
    }
    nat_443_to_anywhere = {
      sg          = "nat"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTPS outbound"
    }

  }
}

resource "aws_security_group" "this" {
  for_each = local.sg_names

  name                   = each.value
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  ingress = []
  egress  = []

  tags = {
    Name = each.value
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.ingress_rules

  security_group_id = aws_security_group.this[each.value.sg].id
  ip_protocol       = each.value.protocol
  from_port         = each.value.protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.protocol == "-1" ? null : each.value.to_port
  description       = each.value.description

  referenced_security_group_id = try(each.value.source_sg, null) != null ? aws_security_group.this[each.value.source_sg].id : null
  cidr_ipv4                    = try(each.value.cidr_ipv4, null)
  prefix_list_id               = try(each.value.prefix_list_id, null)
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = local.egress_rules

  security_group_id = aws_security_group.this[each.value.sg].id
  ip_protocol       = each.value.protocol
  from_port         = each.value.protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.protocol == "-1" ? null : each.value.to_port
  description       = each.value.description

  referenced_security_group_id = try(each.value.target_sg, null) != null ? aws_security_group.this[each.value.target_sg].id : null
  cidr_ipv4                    = try(each.value.cidr_ipv4, null)
}
