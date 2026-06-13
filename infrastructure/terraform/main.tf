# ============================================================
# SECURITY GROUP
# ============================================================

resource "aws_security_group" "zeltan_sg" {

  name        = "${var.project_name}-sg"
  description = "Security group for Zeltan Store — Docker Compose + k3s Kubernetes"

  # ------------------------------------------------------------
  # SSH
  # ------------------------------------------------------------
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ------------------------------------------------------------
  # HTTP
  # ------------------------------------------------------------
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ------------------------------------------------------------
  # HTTPS
  # ------------------------------------------------------------
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ------------------------------------------------------------
  # KUBERNETES API SERVER
  # Required for kubectl access and k3s cluster communication
  # ------------------------------------------------------------
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ------------------------------------------------------------
  # OUTBOUND INTERNET ACCESS
  # ------------------------------------------------------------
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ============================================================
# PRODUCTION EC2 INSTANCE
# t3.small — 2GB RAM, 2 vCPU
# Supports Docker Compose + k3s Kubernetes simultaneously
# ============================================================

resource "aws_instance" "zeltan_server" {

  ami           = var.ami_id
  instance_type = var.instance_type

  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.zeltan_instance_profile.name

  vpc_security_group_ids = [
    aws_security_group.zeltan_sg.id
  ]

  # ------------------------------------------------------------
  # ROOT VOLUME — 20GB
  # Extra space for Docker images + k3s container images
  # Default 8GB is not enough for both stacks
  # ------------------------------------------------------------
  root_block_device {
    volume_size           = var.disk_size_gb
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name        = "${var.project_name}-root-volume"
      Project     = var.project_name
      Environment = var.environment
    }
  }

  # ------------------------------------------------------------
  # BOOTSTRAP SCRIPT
  # Installs Docker, k3s, configures both stacks on first boot
  # ------------------------------------------------------------
  user_data = file("${path.module}/userdata.sh")

  # Recreate EC2 if userdata changes — ensures clean deployments
  user_data_replace_on_change = true

  tags = {
    Name        = "${var.project_name}-server"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ============================================================
# ELASTIC IP
# Static public IP — survives terraform destroy/apply cycles
# Use this IP for DuckDNS and MongoDB Atlas Network Access
# ============================================================

resource "aws_eip" "zeltan_eip" {

  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-eip"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ------------------------------------------------------------
# ELASTIC IP ASSOCIATION
# Attaches static IP to EC2 instance
# ------------------------------------------------------------

resource "aws_eip_association" "zeltan_eip_assoc" {

  instance_id   = aws_instance.zeltan_server.id
  allocation_id = aws_eip.zeltan_eip.id
}
