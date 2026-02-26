# ------------------------------------------------------------------------------
# DB EC2: Primary 1 (subnet a), Read Replica 1 + Arbiter 1 (subnet b)
# ------------------------------------------------------------------------------

locals {
  subnet_a_id = var.private_db_subnet_ids[0]
  subnet_b_id = var.private_db_subnet_ids[1]
}

# Primary 1대 (Private DB subnet a)
resource "aws_instance" "db_primary" {
  count         = 1
  ami           = var.db_ami_id
  instance_type = var.db_primary_instance_type
  subnet_id     = local.subnet_a_id
  key_name      = var.db_key_name

  vpc_security_group_ids = [var.application_sg_id]

  # OS용 루트 디스크 (크기·타입·암호화·인스턴스 삭제 시 볼륨 함께 삭제)
  root_block_device {
    volume_size           = var.db_root_volume_size_gb
    volume_type           = var.db_volume_type
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.project}-${var.environment}-mysql-primary"
    Project     = var.project
    Environment = var.environment
    Role        = "mysql-primary"
  }
}

# Read Replica 1대 (Private DB subnet b)
resource "aws_instance" "db_replica" {
  count         = 1
  ami           = var.db_ami_id
  instance_type = var.db_replica_instance_type
  subnet_id     = local.subnet_b_id
  key_name      = var.db_key_name

  vpc_security_group_ids = [var.application_sg_id]

  # OS용 루트 디스크 (크기·타입·암호화·인스턴스 삭제 시 볼륨 함께 삭제)
  root_block_device {
    volume_size           = var.db_root_volume_size_gb
    volume_type           = var.db_volume_type
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.project}-${var.environment}-mysql-replica-${count.index}"
    Project     = var.project
    Environment = var.environment
    Role        = "mysql-replica"
  }
}

# Arbiter 1대 (Private DB subnet b)
resource "aws_instance" "db_arbiter" {
  count         = 1
  ami           = var.db_ami_id
  instance_type = var.db_arbiter_instance_type
  subnet_id     = local.subnet_b_id
  key_name      = var.db_key_name

  vpc_security_group_ids = [var.application_sg_id]

  # OS용 루트 디스크 (크기·타입·암호화·인스턴스 삭제 시 볼륨 함께 삭제)
  root_block_device {
    volume_size           = var.db_root_volume_size_gb
    volume_type           = var.db_volume_type
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.project}-${var.environment}-mysql-arbiter"
    Project     = var.project
    Environment = var.environment
    Role        = "mysql-arbiter"
  }
}

# ------------------------------------------------------------------------------
# EBS 데이터 볼륨 (DB EC2당 1개, 동일 AZ) + 연결
# ------------------------------------------------------------------------------

# 데이터 볼륨 EBS는 인스턴스와 동일 AZ에 생성해야 attach 가능 (Arbiter는 데이터 미보관이라 제외)
locals {
  db_primary_az = aws_instance.db_primary[0].availability_zone
  db_replica_az = aws_instance.db_replica[0].availability_zone
}

# Primary DB 전용 EBS 볼륨 생성 및 EC2에 /dev/sdf 로 attach (MySQL 데이터 디렉터리용)
resource "aws_ebs_volume" "db_primary_data" {
  count             = 1
  availability_zone = local.db_primary_az
  size              = var.db_data_volume_size_gb
  type              = var.db_volume_type
  encrypted         = true

  tags = {
    Name        = "${var.project}-${var.environment}-mysql-primary-data"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_volume_attachment" "db_primary_data" {
  count       = 1
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.db_primary_data[0].id
  instance_id = aws_instance.db_primary[0].id
}

# Replica DB 전용 EBS 볼륨 생성 및 EC2에 /dev/sdf 로 attach (MySQL 데이터 디렉터리용)
resource "aws_ebs_volume" "db_replica_data" {
  count             = 1
  availability_zone = local.db_replica_az
  size              = var.db_data_volume_size_gb
  type              = var.db_volume_type
  encrypted         = true

  tags = {
    Name        = "${var.project}-${var.environment}-mysql-replica-${count.index}-data"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_volume_attachment" "db_replica_data" {
  count       = 1
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.db_replica_data[count.index].id
  instance_id = aws_instance.db_replica[count.index].id
}


# ------------------------------------------------------------------------------
# S3: FE/업로드용 버킷 (planit-v2-fe-s3-bucket)
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "fe" {
  bucket = var.fe_bucket_name

  tags = {
    Name        = var.fe_bucket_name
    Project     = var.project
    Environment = var.environment
    Purpose     = "fe-static-and-uploads"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "fe" {
  bucket = aws_s3_bucket.fe.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "fe" {
  bucket = aws_s3_bucket.fe.id

  block_public_acls       = true
  block_public_policy    = true
  ignore_public_acls     = true
  restrict_public_buckets = true
}

# FE 버킷 정책은 루트에서 CloudFront 배포 ARN으로 설정 (terraform.tf의 aws_s3_bucket_policy.fe)

# ------------------------------------------------------------------------------
# S3: DB 백업용 버킷 (planit-db-backup)
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "backup" {
  bucket = var.backup_bucket_name

  tags = {
    Name        = var.backup_bucket_name
    Project     = var.project
    Environment = var.environment
    Purpose     = "db-backup"
  }
}

resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls     = true
  restrict_public_buckets = true
}

# 7일 후 Glacier Instant Retrieval, 90일 후 삭제
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "archive-and-expire"
    status = "Enabled"

    filter {} # 전체 버킷 대상

    transition {
      days          = 7
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 90
    }
  }
}
