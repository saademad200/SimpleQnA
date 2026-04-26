# ─────────────────────────────────────────────
# AMI — latest Amazon Linux 2023 (x86_64)
# ─────────────────────────────────────────────

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─────────────────────────────────────────────
# Security group
# ─────────────────────────────────────────────

resource "aws_security_group" "backend" {
  name        = "simpleqna-backend-sg"
  description = "Allow inbound traffic to the backend and SSH"

  ingress {
    description = "FastAPI backend"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "SimpleQnA"
  }
}

# ─────────────────────────────────────────────
# EC2 instance — runs the full docker-compose stack
# user_data installs Docker, clones the repo, and starts services
# ─────────────────────────────────────────────

resource "aws_instance" "backend" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.backend.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # System update and Docker install
    dnf update -y
    dnf install -y docker git
    systemctl start docker
    systemctl enable docker

    # Docker Compose v2 plugin
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    # Clone repo and configure
    git clone ${var.github_repo} /app
    cat > /app/.env <<ENVEOF
    LLM_API_KEY=${var.llm_api_key}
    ENVEOF

    # Start all services
    cd /app && docker compose up -d
  EOF

  tags = {
    Name    = "simpleqna-backend"
    Project = "SimpleQnA"
  }
}
