# ============================================================
# SECURITY GROUP
# ============================================================

resource "aws_security_group" "zeltan_sg" {

  name        = "${var.project_name}-sg"
  description = "Security group for Zeltan Store backend"

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
  # OUTBOUND INTERNET ACCESS
  # ------------------------------------------------------------
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ============================================================
# PRODUCTION EC2 INSTANCE
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
  # BOOTSTRAP SCRIPT
  # ------------------------------------------------------------
  user_data = file("${path.module}/userdata.sh")

  user_data_replace_on_change = true

  tags = {
    Name        = "${var.project_name}-server"
    Environment = "production"
  }
}

# ============================================================
# ELASTIC IP
# ============================================================

resource "aws_eip" "zeltan_eip" {

  domain = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

resource "aws_eip_association" "zeltan_eip_assoc" {

  instance_id   = aws_instance.zeltan_server.id
  allocation_id = aws_eip.zeltan_eip.id
}