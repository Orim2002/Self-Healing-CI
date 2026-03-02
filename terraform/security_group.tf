resource "aws_security_group" "rds_sg" {
  name        = "pipeline-registry-rds-sg"
  description = "Allow PostgreSQL access from trusted IPs only"

  # Allow inbound PostgreSQL from your IP
  dynamic "ingress" {
    for_each = var.allowed_cidrs
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "PostgreSQL access from ${ingress.value}"
    }
  }

  # Allow inbound PostgreSQL from Jenkins EC2 dynamically
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.jenkins.public_ip}/32"]
    description = "PostgreSQL access from Jenkins EC2"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name    = "pipeline-registry-rds-sg"
    Project = "self-healing-pipeline"
  }
}