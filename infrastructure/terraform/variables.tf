# ============================================================
# VARIABLES — ZELTAN STORE TERRAFORM
# ============================================================

# ------------------------------------------------------------
# AWS REGION
# ------------------------------------------------------------
variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "us-east-1"
}

# ------------------------------------------------------------
# EC2 INSTANCE TYPE
# t3.small  = 2GB RAM, 2 vCPU — minimum for Docker + k3s
# t3.medium = 4GB RAM, 2 vCPU — recommended for production
# ------------------------------------------------------------
variable "instance_type" {
  description = "EC2 instance type — t3.small minimum for Docker Compose + k3s"
  type        = string
  default     = "t3.small"
}

# ------------------------------------------------------------
# EC2 DISK SIZE
# 20GB minimum for Docker images + k3s container images
# ------------------------------------------------------------
variable "disk_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

# ------------------------------------------------------------
# EC2 AMI
# ------------------------------------------------------------
variable "ami_id" {
  description = "Ubuntu Server 22.04 LTS AMI ID (us-east-1: ami-0c7217cdde317cfec)"
  type        = string
}

# ------------------------------------------------------------
# SSH KEY NAME
# ------------------------------------------------------------
variable "key_name" {
  description = "AWS EC2 SSH key pair name"
  type        = string
}

# ------------------------------------------------------------
# PROJECT TAG
# ------------------------------------------------------------
variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "zeltan-store"
}

# ------------------------------------------------------------
# ENVIRONMENT TAG
# ------------------------------------------------------------
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}
