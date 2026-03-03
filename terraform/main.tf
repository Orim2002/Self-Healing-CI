terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "self-healing-ci-tfstate"
    key            = "self-healing-ci/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "self-healing-ci-terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "ec2" {
  source        = "./modules/ec2"
  instance_type = var.jenkins_instance_type
  key_name      = var.jenkins_key_name
  allowed_cidrs = var.allowed_cidrs
  aws_region    = var.aws_region
}

module "rds" {
  source         = "./modules/rds"
  db_name        = var.db_name
  instance_class = var.db_instance
  db_user        = var.db_user
  db_password    = var.db_password
  allowed_cidrs  = var.allowed_cidrs
  jenkins_ip     = module.ec2.public_ip
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.eks_cluster_name
  kubernetes_version = var.eks_kubernetes_version
  node_instance_type = var.eks_node_instance_type
  desired_size       = var.eks_desired_size
  min_size           = var.eks_min_size
  max_size           = var.eks_max_size
}

module "ecr" {
  source        = "./modules/ecr"
  service_names = var.ecr_service_names
}