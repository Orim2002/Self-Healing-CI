resource "aws_db_instance" "pipeline_registry" {
  identifier        = "pipeline-registry-db"
  engine            = "postgres"
  engine_version    = "17.2"
  instance_class    = var.db_instance
  db_name           = var.db_name
  username          = var.db_user
  password          = var.db_password

  # Storage (free tier)
  allocated_storage       = 20
  storage_type            = "gp2"
  storage_encrypted       = true

  # Connectivity
  publicly_accessible     = true
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  skip_final_snapshot     = true   # for dev — set false in production

  # Maintenance
  auto_minor_version_upgrade = true
  deletion_protection        = false  # for dev — set true in production

  tags = {
    Name    = "pipeline-registry-db"
    Project = "self-healing-pipeline"
  }
}