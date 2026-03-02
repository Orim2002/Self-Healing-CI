output "rds_endpoint" {
  description = "RDS connection endpoint — use this as DB_HOST in your .env"
  value       = aws_db_instance.pipeline_registry.endpoint
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.pipeline_registry.port
}

output "rds_db_name" {
  description = "Database name"
  value       = aws_db_instance.pipeline_registry.db_name
}

output "security_group_id" {
  description = "Security group ID attached to RDS"
  value       = aws_security_group.rds_sg.id
}

output "jenkins_public_ip" {
  description = "Jenkins EC2 public IP — use this to access Jenkins UI"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins web UI URL"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_ssh" {
  description = "SSH command to connect to Jenkins"
  value       = "ssh -i ${var.jenkins_key_name}.pem ubuntu@${aws_instance.jenkins.public_ip}"
}