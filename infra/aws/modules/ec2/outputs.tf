# =============================================================================
# EC2 Module Outputs
# =============================================================================

output "bastion_public_ip" {
  description = "Bastion Host Public IP"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Bastion Host Instance ID"
  value       = aws_instance.bastion.id
}

output "mgmt_server_private_ip" {
  description = "Management Server Private IP"
  value       = aws_instance.mgmt.private_ip
}

output "mgmt_server_instance_id" {
  description = "Management Server Instance ID"
  value       = aws_instance.mgmt.id
}

output "ssh_key_name" {
  description = "SSH Key Pair Name"
  value       = aws_key_pair.generated.key_name
}

output "ssh_private_key_path" {
  description = "SSH Private Key File Path"
  value       = local_file.private_key.filename
}

