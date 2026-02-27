# ------------------------------------------------------------------------------
# 데이터 소스: 가용 영역, AMI
# ------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project}-${var.environment}-vpc"
    Project     = var.project
    Environment = var.environment
  }
}

# ------------------------------------------------------------------------------
# Internet Gateway
# ------------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-${var.environment}-igw"
    Project     = var.project
    Environment = var.environment
  }
}

# ------------------------------------------------------------------------------
# 서브넷 (AZ 2개 × Public / Private App / Private DB)
# 설계: Public(ALB, NAT), Private a1(Application), Private a2(Database)
# ------------------------------------------------------------------------------

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # 이 스택 전용 VPC 내 서브넷 (vpc_cidr 기준 자동 계산. 운영 10.0.0.0/16과 겹치지 않도록 기본 10.1.0.0/16 사용)
  # cidrsubnet(prefix, newbits, netnum): prefix를 newbits만큼 확장한 서브넷들 중 netnum번째 CIDR을 반환 (예: 10.1.0.0/16, 8, 2 → 10.1.2.0/24)
  public_cidrs      = [cidrsubnet(var.vpc_cidr, 8, 2), cidrsubnet(var.vpc_cidr, 8, 3)]
  private_app_cidrs  = [cidrsubnet(var.vpc_cidr, 8, 10), cidrsubnet(var.vpc_cidr, 8, 11)]
  private_db_cidrs   = [cidrsubnet(var.vpc_cidr, 8, 20), cidrsubnet(var.vpc_cidr, 8, 21)]
}

# Public
resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project}-${var.environment}-public-${local.azs[count.index]}"
    Project     = var.project
    Environment = var.environment
    Type        = "public"
  }
}

# Private (Application Layer: WAS, Queue 등)
resource "aws_subnet" "private_app" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_app_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name        = "${var.project}-${var.environment}-private-app-${local.azs[count.index]}"
    Project     = var.project
    Environment = var.environment
    Type        = "private-app"
  }
}

# Private (Database Layer: MySQL, MongoDB 등)
resource "aws_subnet" "private_db" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_db_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name        = "${var.project}-${var.environment}-private-db-${local.azs[count.index]}"
    Project     = var.project
    Environment = var.environment
    Type        = "private-db"
  }
}

# ------------------------------------------------------------------------------
# Route Table: Public (Public a, b → IGW. ALB 및 NAT 인스턴스 외부 통신)
# ------------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project}-${var.environment}-public-rt"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# NAT Instance (Public 서브넷 AZ당 1대, 총 2대. Private App 아웃바운드용)
# ------------------------------------------------------------------------------

resource "aws_security_group" "nat" {
  count       = var.enable_nat_instance ? 1 : 0
  name        = "${var.project}-${var.environment}-nat-sg"
  description = "NAT Instance: Allow all from private subnets (app+db), all outbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "All from private subnets (app+db, NAT forwarding)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat(local.private_app_cidrs, local.private_db_cidrs)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-nat-sg"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_instance" "nat" {
  count         = var.enable_nat_instance ? 2 : 0
  ami           = var.nat_instance_ami_id
  instance_type = var.nat_instance_type
  subnet_id     = aws_subnet.public[count.index].id
  key_name      = var.nat_instance_key_name

  vpc_security_group_ids = [aws_security_group.nat[0].id]
  source_dest_check      = false

  user_data = <<-EOT
    #!/bin/bash
    set -e  # 명령 실패 시 즉시 종료

    # NAT 기능을 위해 iptables 및 영구 저장 도구 설치
    apt-get update && apt-get install -y iptables netfilter-persistent

    # Private 서브넷에서 나온 트래픽을 NAT해서 인터넷으로 내보냄
    iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE

    # 재부팅 후에도 iptables 규칙 유지
    netfilter-persistent save

    # 커널 IP 포워딩 활성화 (NAT 필수)
    sysctl -w net.ipv4.ip_forward=1
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/99-nat.conf
  EOT

  tags = {
    Name        = "${var.project}-${var.environment}-nat-${count.index}"
    Project     = var.project
    Environment = var.environment
  }
}

# ------------------------------------------------------------------------------
# Route Table: Private (AZ별 1개 — Private App + DB 해당 AZ의 NAT Instance 경유)
# RT-Private-A: Private a1(app), a2(db) → NAT a | RT-Private-B: Private b1(app), b2(db) → NAT b
# ------------------------------------------------------------------------------

resource "aws_route_table" "private_az" {
  count  = 2
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_instance ? [1] : []
    content {
      cidr_block           = "0.0.0.0/0"
      network_interface_id = aws_instance.nat[count.index].primary_network_interface_id
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-private-rt-${count.index}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_az[count.index].id
}

resource "aws_route_table_association" "private_db" {
  count          = length(aws_subnet.private_db)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_az[count.index].id
}
