variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "pipelinedb"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_user" {
  description = "Master username"
  type        = string
}

variable "db_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "allowed_cidrs" {
  description = "IPs allowed to connect to RDS"
  type        = list(string)
}

variable "jenkins_ip" {
  description = "Jenkins EC2 public IP (dynamic reference)"
  type        = string
}