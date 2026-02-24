output "security_group_ids" {
  description = "보안그룹 ID 매핑"
  value = {
    alb   = aws_security_group.this["alb"].id
    ai    = aws_security_group.this["ai"].id
    be    = aws_security_group.this["be"].id
    db    = aws_security_group.this["db"].id
    queue = aws_security_group.this["queue"].id
    nat   = aws_security_group.this["nat"].id
  }
}
