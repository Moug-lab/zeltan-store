# ============================================================
# OUTPUTS
# ============================================================

output "ec2_public_ip" {
  description = "Production EC2 dynamic public IP (may change on restart)"
  value       = aws_instance.zeltan_server.public_ip
}

output "ec2_public_dns" {
  description = "Production EC2 public DNS"
  value       = aws_instance.zeltan_server.public_dns
}

output "elastic_ip" {
  description = "Elastic IP for Zeltan Store (static - use this for DNS)"
  value       = aws_eip.zeltan_eip.public_ip
}

output "elastic_ip_dns" {
  description = "Elastic IP DNS hostname"
  value       = aws_eip.zeltan_eip.public_dns
}