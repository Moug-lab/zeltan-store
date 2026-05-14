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

  key_name = var.key_name

  vpc_security_group_ids = [
    aws_security_group.zeltan_sg.id
  ]

  tags = {
    Name = "${var.project_name}-server"
  }
}