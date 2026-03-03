# ── EC2 ───────────────────────────────────────────────────────────────────────
output "jenkins_url" {
  description = "Jenkins web UI"
  value       = module.ec2.jenkins_url
}

output "jenkins_public_ip" {
  description = "Jenkins EC2 public IP"
  value       = module.ec2.public_ip
}

output "jenkins_ssh" {
  description = "SSH command for Jenkins"
  value       = module.ec2.ssh_command
}

# ── RDS ───────────────────────────────────────────────────────────────────────
output "rds_endpoint" {
  description = "RDS connection endpoint"
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "RDS port"
  value       = module.rds.port
}

output "rds_db_name" {
  description = "Database name"
  value       = module.rds.db_name
}

# ── EKS ───────────────────────────────────────────────────────────────────────
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = module.eks.kubeconfig_command
}

# ── ECR ───────────────────────────────────────────────────────────────────────
output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}