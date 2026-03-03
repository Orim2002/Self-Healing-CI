output "public_ip" {
  description = "Jenkins EC2 public IP"
  value       = aws_eip.jenkins.public_ip
}

output "private_ip" {
  description = "Jenkins EC2 private IP"
  value       = aws_instance.jenkins.private_ip
}

output "jenkins_url" {
  description = "Jenkins web UI URL"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to Jenkins"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_eip.jenkins.public_ip}"
}

output "security_group_id" {
  description = "Jenkins security group ID"
  value       = aws_security_group.jenkins_sg.id
}