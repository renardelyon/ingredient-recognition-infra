terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.92"
    }
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = var.ami_type
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "ec2_security_group" {
  name        = "${var.app_name}-sg"
  description = "Security group for ${var.app_name} application"
  vpc_id      = var.aws_security_group_var.vpc_id

  tags = {
    "Name" = "${var.app_name}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_access" {
  security_group_id = aws_security_group.ec2_security_group.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.aws_security_group_var.ssh_allowed_ip
}

resource "aws_vpc_security_group_ingress_rule" "http_access" {
  security_group_id = aws_security_group.ec2_security_group.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "https_access" {
  count             = var.enable_nginx_ssl ? 1 : 0
  security_group_id = aws_security_group.ec2_security_group.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app_access" {
  security_group_id = aws_security_group.ec2_security_group.id
  from_port         = var.aws_security_group_var.app_port
  to_port           = var.aws_security_group_var.app_port
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "outbound_access" {
  security_group_id = aws_security_group.ec2_security_group.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "${var.app_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_name}-ec2-role"
  }
}

resource "aws_iam_role_policy" "custom_policies" {
  for_each = var.iam_policies

  name = "${var.app_name}-${each.key}-policy"
  role = aws_iam_role.ec2_role.name

  policy = each.value.policy
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.app_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Key Pair (optional - create one if you don't have it)
resource "aws_key_pair" "deployer" {
  count      = var.keypair_creation_config.create_key_pair ? 1 : 0
  key_name   = "${var.app_name}-key"
  public_key = var.keypair_creation_config.public_key

  tags = {
    Name = "${var.app_name}-key"
  }
}

# User data script to setup the application
locals {
  ecr_url = "${var.aws_caller_identity_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"


  user_data = <<-EOF
    #!/bin/bash
    
    # Update system
    dnf update -y
    
    # Install Docker
    dnf install -y docker
    systemctl start docker
    systemctl enable docker

    %{if var.enable_nginx_ssl && var.domain_name != null}
    echo "🔧 Installing Nginx and Certbot..."
    dnf install -y nginx certbot python3-certbot-nginx

    # Configure Nginx as reverse proxy
    cat > /etc/nginx/conf.d/app.conf << 'NGINXCONF'

server {
    listen 80;
    server_name ${var.domain_name};

    # Backend API
    location / {
        proxy_pass http://localhost:${var.app_port}/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
NGINXCONF

    # Remove default nginx config
    rm -f /etc/nginx/conf.d/default.conf

    # Test and start Nginx
    echo "🚀 Starting Nginx..."
    nginx -t
    systemctl enable nginx
    systemctl start nginx

    # Get SSL certificate with retries
    echo "🔐 Requesting Let's Encrypt certificate..."
    for i in 1 2 3 4 5; do
      certbot --nginx -d ${var.domain_name} \
        --non-interactive \
        --agree-tos \
        --email ${var.letsencrypt_email} \
        --redirect && break
      echo "Certbot attempt $i failed, waiting 30s..."
      sleep 30
    done

    # Setup auto-renewal cron
    echo "0 0,12 * * * root certbot renew --quiet --post-hook 'systemctl reload nginx'" > /etc/cron.d/certbot-renew

    echo "✅ Nginx + SSL setup complete!"
    %{endif}

    echo "✅ EC2 setup complete!"

  EOF
}

# EC2 Instance
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.keypair_creation_config.create_key_pair ? aws_key_pair.deployer[0].key_name : ""
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  subnet_id              = var.subnet_id

  user_data = base64encode(local.user_data)

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.app_name}-instance"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP (optional but recommended)
resource "aws_eip" "app" {
  count    = var.use_elastic_ip ? 1 : 0
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name = "${var.app_name}-eip"
  }
}

resource "aws_ec2_instance_state" "app_state" {
  instance_id = aws_instance.app.id
  state       = var.instance_state # Use "running" to start it again
}


