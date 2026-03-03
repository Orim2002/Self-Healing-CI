variable "service_names" {
  description = "List of service names to create ECR repositories for"
  type        = list(string)
  default     = ["sample-app"]
}

