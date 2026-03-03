output "repository_urls" {
  description = "ECR repository URLs for each service"
  value = {
    for name, repo in aws_ecr_repository.services :
    name => repo.repository_url
  }
}

output "registry_id" {
  description = "ECR registry ID"
  value       = values(aws_ecr_repository.services)[0].registry_id
}