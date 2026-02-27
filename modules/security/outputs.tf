output "security_group_ids" {
  description = "보안그룹 ID 매핑"
  value = {
    alb   = aws_security_group.this["alb"].id
    ai    = aws_security_group.this["ai"].id
    be    = aws_security_group.this["be"].id
    db    = aws_security_group.this["db"].id
    queue = aws_security_group.this["queue"].id
  }
}

output "iam_role_names" {
  description = "IAM Role 이름 매핑"
  value = {
    ec2_ssm = aws_iam_role.ec2_ssm.name
    ec2_s3  = aws_iam_role.ec2_s3.name
  }
}

output "iam_instance_profile_names" {
  description = "IAM Instance Profile 이름 매핑"
  value = {
    ec2_ssm = aws_iam_instance_profile.ec2_ssm.name
    ec2_s3  = aws_iam_instance_profile.ec2_s3.name
  }
}
