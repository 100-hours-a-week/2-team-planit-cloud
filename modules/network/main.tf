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

  # CIDR 블록 (고정 설계)
  public_cidrs      = ["10.0.2.0/24", "10.0.3.0/24"]
  private_app_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
  private_db_cidrs   = ["10.0.20.0/24", "10.0.21.0/24"]
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
# Route Table: Public
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
# NAT Instance (Public 서브넷 1대, Private App 아웃바운드용)
# ------------------------------------------------------------------------------

resource "aws_security_group" "nat" {
  count       = var.enable_nat_instance ? 1 : 0
  name        = "${var.project}-${var.environment}-nat-sg"
  description = "NAT Instance: Allow all from private app subnets, all outbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "All from private app (NAT forwarding)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.private_app_cidrs
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
  count         = var.enable_nat_instance ? 1 : 0
  ami           = var.nat_instance_ami_id
  instance_type = var.nat_instance_type
  subnet_id     = aws_subnet.public[0].id
  key_name      = var.nat_instance_key_name

  vpc_security_group_ids = [aws_security_group.nat[0].id]
  source_dest_check      = false

  user_data = <<-EOT
    #!/bin/bash
    set -e
    apt-get update && apt-get install -y iptables netfilter-persistent
    iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
    netfilter-persistent save
    sysctl -w net.ipv4.ip_forward=1
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/99-nat.conf
  EOT

  tags = {
    Name        = "${var.project}-${var.environment}-nat"
    Project     = var.project
    Environment = var.environment
  }
}

# ------------------------------------------------------------------------------
# Route Table: Private App (NAT Instance 경유 아웃바운드)
# ------------------------------------------------------------------------------

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_instance ? [1] : []
    content {
      cidr_block           = "0.0.0.0/0"
      network_interface_id = aws_instance.nat[0].primary_network_interface_id
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-private-app-rt"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app.id
}

# ------------------------------------------------------------------------------
# Route Table: Private DB (인터넷 아웃바운드 없음)
# ------------------------------------------------------------------------------

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-${var.environment}-private-db-rt"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_db" {
  count          = length(aws_subnet.private_db)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}
