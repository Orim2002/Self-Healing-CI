output "endpoint" {
  description = "RDS connection endpoint"
  value       = aws_db_instance.pipeline_registry.endpoint
}

output "port" {
  description = "RDS port"
  value       = aws_db_instance.pipeline_registry.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.pipeline_registry.db_name
}

output "security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds_sg.id
}