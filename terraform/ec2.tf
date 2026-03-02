# ─── AMI: Latest Ubuntu 22.04 (dynamic lookup) ────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical's official AWS account

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─── Security Group for Jenkins ───────────────────────────────────────────────
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH and Jenkins web UI access"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "SSH from trusted IPs"
  }

  # Jenkins Web UI
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "Jenkins UI from trusted IPs"
  }

  # All outbound traffic
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

# ─── Jenkins EC2 Instance ─────────────────────────────────────────────────────
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.jenkins_instance_type
  key_name               = var.jenkins_key_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  # Auto-install Jenkins on first boot
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
    pip3 install psycopg2-binary

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