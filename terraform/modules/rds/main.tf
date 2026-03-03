# ── Security Group ────────────────────────────────────────────────────────────
resource "aws_security_group" "rds_sg" {
  name        = "pipeline-registry-rds-sg"
  description = "Allow PostgreSQL access from trusted IPs only"

  dynamic "ingress" {
    for_each = var.allowed_cidrs
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "PostgreSQL from ${ingress.value}"
    }
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${var.jenkins_ip}/32"]
    description = "PostgreSQL from Jenkins EC2"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "pipeline-rds-sg"
    Project = "self-healing-pipeline"
  }
}

# ── RDS Instance ──────────────────────────────────────────────────────────────
resource "aws_db_instance" "pipeline_registry" {
  identifier        = "pipeline-registry-db"
  engine            = "postgres"
  engine_version    = "17.2"
  instance_class    = var.instance_class
  db_name           = var.db_name
  username          = var.db_user
  password          = var.db_password

  allocated_storage      = 20
  storage_type           = "gp2"
  storage_encrypted      = true
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true

  auto_minor_version_upgrade = true
  deletion_protection        = false

  tags = {
    Name    = "pipeline-registry-db"
    Project = "self-healing-pipeline"
  }
}