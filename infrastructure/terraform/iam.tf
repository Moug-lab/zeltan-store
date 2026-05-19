# ============================================================
# IAM ROLE FOR EC2
# ============================================================

resource "aws_iam_role" "zeltan_ec2_role" {

  name = "zeltan-ec2-role"

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
}
# ============================================================
# INSTANCE PROFILE
# ============================================================

resource "aws_iam_instance_profile" "zeltan_instance_profile" {

  name = "zeltan-instance-profile"

  role = aws_iam_role.zeltan_ec2_role.name
}
# ============================================================
# IAM POLICY ATTACHMENT
# ============================================================

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {

  role = aws_iam_role.zeltan_ec2_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}