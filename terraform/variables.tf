variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "pipeline_db"
}

variable "db_instance" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_user" {
  description = "Master username for PostgreSQL"
  type        = string
}

variable "db_password" {
  description = "Master password for PostgreSQL"
  type        = string
  sensitive   = true   # hides value in terraform output
}

variable "allowed_cidrs" {
  description = "List of CIDR blocks allowed to connect to RDS (your IP)"
  type        = list(string)
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
  default     = "t3.medium"
}

variable "jenkins_key_name" {
  description = "AWS key pair name for SSH access to Jenkins EC2"
  type        = string
}