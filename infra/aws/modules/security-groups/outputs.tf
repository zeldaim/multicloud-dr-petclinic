# =============================================================================
# Security Groups Module Outputs
# =============================================================================

output "bastion_sg_id" {
  description = "Bastion Security Group ID"
  value       = aws_security_group.bastion.id
}

output "mgmt_sg_id" {
  description = "Management Server Security Group ID"
  value       = aws_security_group.mgmt.id
}

output "rds_sg_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}

output "eks_cluster_sg_id" {
  description = "EKS Cluster Security Group ID"
  value       = aws_security_group.eks_cluster.id
}

