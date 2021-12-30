# --- networking/outputs.tf ---

output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.my_rds_subnet_group.*.name
}

output "db_security_group" {
  value = [aws_security_group.my_sg["rds"].id]
}