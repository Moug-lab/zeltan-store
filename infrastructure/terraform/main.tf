# ============================================================
# SECURITY GROUP
# ============================================================

resource "aws_security_group" "zeltan_sg" {

  name        = "${var.project_name}-sg"
  description = "Security group for Zeltan Store backend"

  # SSH ACCESS
  ingress {
    description = "SSH"

    from_port = 22
    to_port   = 22

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  # BACKEND API ACCESS
  ingress {
    description = "Backend API"

    from_port = 5000
    to_port   = 5000

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  # OUTBOUND INTERNET ACCESS
  egress {
    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ============================================================
# EC2 INSTANCE
# ============================================================

resource "aws_instance" "zeltan_server" {

  ami           = var.ami_id
  instance_type = var.instance_type

  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.zeltan_instance_profile.name

  vpc_security_group_ids = [
    aws_security_group.zeltan_sg.id
  ]

  # ── BOOTSTRAP SCRIPT ─────────────────────────────────────
  # Runs automatically when EC2 first boots.
  # Installs Docker, pulls image, starts container.
  # file() reads userdata.sh from same folder as main.tf
  user_data = file("${path.module}/userdata.sh")

  # Force replacement when userdata changes
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-server"
  }
}