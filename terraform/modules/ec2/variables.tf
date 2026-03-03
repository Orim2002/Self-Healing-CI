variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "AWS key pair name for SSH"
  type        = string
}

variable "allowed_cidrs" {
  description = "IPs allowed to SSH and access Jenkins"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}