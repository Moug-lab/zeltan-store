# ============================================================
# VARIABLES — ZELTAN STORE TERRAFORM
# ============================================================

# AWS REGION
variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "us-east-1"
}

# EC2 INSTANCE TYPE
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

# EC2 AMI
variable "ami_id" {
  description = "Ubuntu Server AMI ID"
  type        = string
}

# SSH KEY NAME
variable "key_name" {
  description = "AWS EC2 SSH key pair name"
  type        = string
}

# PROJECT TAG
variable "project_name" {
  description = "Project name tag"
  type        = string
  default     = "zeltan-store"
}