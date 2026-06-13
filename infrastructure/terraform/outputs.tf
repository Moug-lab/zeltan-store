# ============================================================
# OUTPUTS
# ============================================================

# ------------------------------------------------------------
# EC2 DYNAMIC PUBLIC IP
# Changes on stop/start — do not use for DNS
# ------------------------------------------------------------
output "ec2_public_ip" {
  description = "Production EC2 dynamic public IP (changes on restart — use elastic_ip for DNS)"
  value       = aws_instance.zeltan_server.public_ip
}

# ------------------------------------------------------------
# EC2 PUBLIC DNS
# ------------------------------------------------------------
output "ec2_public_dns" {
  description = "Production EC2 public DNS"
  value       = aws_instance.zeltan_server.public_dns
}

# ------------------------------------------------------------
# ELASTIC IP — USE THIS FOR:
# 1. DuckDNS update after terraform apply
# 2. MongoDB Atlas Network Access whitelist
# 3. SSH connection
# ------------------------------------------------------------
output "elastic_ip" {
  description = "Static Elastic IP — use for DuckDNS, MongoDB Atlas, and SSH"
  value       = aws_eip.zeltan_eip.public_ip
}

output "elastic_ip_dns" {
  description = "Elastic IP DNS hostname"
  value       = aws_eip.zeltan_eip.public_dns
}

# ------------------------------------------------------------
# SSH COMMAND — ready to copy/paste
# ------------------------------------------------------------
output "ssh_command" {
  description = "SSH command to connect to production EC2"
  value       = "ssh -i ~/.ssh/zeltan-key.pem ubuntu@${aws_eip.zeltan_eip.public_ip}"
}

# ------------------------------------------------------------
# INSTANCE INFO
# ------------------------------------------------------------
output "instance_type" {
  description = "EC2 instance type deployed"
  value       = aws_instance.zeltan_server.instance_type
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.zeltan_server.id
}
