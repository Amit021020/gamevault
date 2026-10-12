output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.gamevault.name
}

output "cluster_id" {
  description = "ID of the EKS cluster"
  value       = aws_eks_cluster.gamevault.id
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint"
  value       = aws_eks_cluster.gamevault.endpoint
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.gamevault.version
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.gamevault.arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded EKS cluster CA certificate"
  value       = aws_eks_cluster.gamevault.certificate_authority[0].data
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster"
  value       = aws_eks_cluster.gamevault.identity[0].oidc[0].issuer
}

output "node_group_name" {
  description = "Name of the EKS managed node group"
  value       = aws_eks_node_group.gamevault.node_group_name
}
output "ebs_csi_driver_addon_name" {
  description = "EBS CSI Driver EKS add-on"
  value       = aws_eks_addon.ebs_csi_driver.addon_name
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role used by the EBS CSI Driver"
  value       = aws_iam_role.ebs_csi.arn
}