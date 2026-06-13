# ============================================================
# IAM ROLE FOR EC2
# Allows EC2 to authenticate with MongoDB Atlas via AWS IAM
# and use SSM Session Manager for secure access
# ============================================================

resource "aws_iam_role" "zeltan_ec2_role" {

  name        = "zeltan-ec2-role"
  description = "IAM role for Zeltan Store EC2 — MongoDB Atlas IAM auth + SSM"

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
    Name        = "zeltan-ec2-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ============================================================
# INSTANCE PROFILE
# Attaches IAM role to EC2 instance
# ============================================================

resource "aws_iam_instance_profile" "zeltan_instance_profile" {

  name = "zeltan-instance-profile"
  role = aws_iam_role.zeltan_ec2_role.name

  tags = {
    Name        = "zeltan-instance-profile"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ============================================================
# SSM MANAGED INSTANCE CORE
# Enables AWS Systems Manager — secure shell without opening
# port 22, session logging, patch management
# ============================================================

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {

  role       = aws_iam_role.zeltan_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ============================================================
# ECR READ-ONLY ACCESS
# Allows EC2 to pull Docker images from ECR if needed
# ============================================================

resource "aws_iam_role_policy_attachment" "ecr_read_only" {

  role       = aws_iam_role.zeltan_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
