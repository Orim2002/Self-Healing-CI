resource "aws_ecr_repository" "services" {
  for_each = toset(var.service_names)

  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = each.key
    Project = "self-healing-pipeline"
  }
}