output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.pipeline.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.pipeline.endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = aws_eks_cluster.pipeline.version
}

output "kubeconfig_command" {
  description = "Command to configure kubectl for EKS"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.pipeline.name} --region us-east-1"
}