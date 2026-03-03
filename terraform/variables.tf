# ── Global ────────────────────────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "allowed_cidrs" {
  description = "Your IP (format: x.x.x.x/32)"
  type        = list(string)
}

# ── EC2 ───────────────────────────────────────────────────────────────────────
variable "jenkins_instance_type" {
  description = "Jenkins EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "jenkins_key_name" {
  description = "AWS key pair name"
  type        = string
}

# ── RDS ───────────────────────────────────────────────────────────────────────
variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "pipelinedb"
}

variable "db_instance" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_user" {
  description = "Database master username"
  type        = string
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

# ── EKS ───────────────────────────────────────────────────────────────────────
variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "self-healing-pipeline"
}

variable "eks_kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "eks_node_instance_type" {
  description = "EKS worker node instance type"
  type        = string
  default     = "t3.medium"
}

variable "eks_desired_size" {
  description = "Desired worker node count"
  type        = number
  default     = 2
}

variable "eks_min_size" {
  description = "Minimum worker node count"
  type        = number
  default     = 1
}

variable "eks_max_size" {
  description = "Maximum worker node count"
  type        = number
  default     = 3
}

# ── ECR ───────────────────────────────────────────────────────────────────────
variable "ecr_service_names" {
  description = "Services to create ECR repositories for"
  type        = list(string)
  default     = ["sample-app"]
}