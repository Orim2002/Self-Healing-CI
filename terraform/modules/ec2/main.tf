# ── AMI: Latest Ubuntu 22.04 ──────────────────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Security Group ────────────────────────────────────────────────────────────
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH and Jenkins web UI access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "SSH access"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "Jenkins UI"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP public access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS public access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "jenkins-sg"
    Project = "self-healing-pipeline"
  }
}

# ── IAM Role for Jenkins EC2 ──────────────────────────────────────────────────
resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# ECR access — pull images
resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# EKS access — manage deployments
resource "aws_iam_role_policy_attachment" "jenkins_eks" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy" "jenkins_eks_access" {
  name = "jenkins-eks-access"
  role = aws_iam_role.jenkins_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ]
      Resource = "*"
    }]
  })
}

# Instance Profile — attaches role to EC2
resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-profile"
  role = aws_iam_role.jenkins_role.name
}

# ── Jenkins EC2 Instance ──────────────────────────────────────────────────────
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    set -e

    apt update -y
    apt upgrade -y

    apt install -y openjdk-21-jre

    wget -O /etc/apt/keyrings/jenkins-keyring.asc \
      https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
    echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
      https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
      /etc/apt/sources.list.d/jenkins.list > /dev/null
    apt update
    apt install -y jenkins

    apt install -y docker.io
    usermod -aG docker jenkins
    usermod -aG docker ubuntu

    apt install -y python3-pip libpq-dev
    pip3 install pyyaml requests python-dotenv psycopg2-binary

    apt install -y unzip

    curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o awscliv2.zip
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws/

    curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/

    apt install -y nginx

    cat > /etc/nginx/sites-available/jenkins << 'NGINX'
    server {
        listen 80;
        server_name jenkins.orimatest.com;

        location / {
            proxy_pass         http://127.0.0.1:8080;
            proxy_http_version 1.1;
            proxy_set_header   Host              $host;
            proxy_set_header   X-Real-IP         $remote_addr;
            proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto $scheme;
        }
    }
    NGINX

    ln -s /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    systemctl enable nginx
    systemctl start nginx
    systemctl enable jenkins
    systemctl start jenkins
    systemctl enable docker
    systemctl start docker

    echo "Jenkins setup complete!"
  EOF

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }

  tags = {
    Name    = "jenkins-server"
    Project = "self-healing-pipeline"
  }
}

resource "aws_eip" "jenkins" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = {
    Name    = "jenkins-eip"
    Project = "self-healing-pipeline"
  }
}