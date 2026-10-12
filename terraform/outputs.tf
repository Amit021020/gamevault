

# VPC / NETWORK OUTPUTS


output "vpc_id" {
  description = "ID of the GameVault VPC"
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the GameVault VPC"
  value       = module.network.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the GameVault public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the GameVault private subnets"
  value       = module.network.private_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the GameVault Internet Gateway"
  value       = module.network.internet_gateway_id
}

output "alb_security_group_id" {
  description = "Security group ID used by the GameVault ALB"
  value       = module.network.alb_security_group_id
}



# EKS OUTPUTS


output "eks_cluster_name" {
  description = "Name of the GameVault EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_id" {
  description = "ID of the GameVault EKS cluster"
  value       = module.eks.cluster_id
}

output "eks_cluster_arn" {
  description = "ARN of the GameVault EKS cluster"
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "API endpoint of the GameVault EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_kubernetes_version" {
  description = "Kubernetes version of the GameVault EKS cluster"
  value       = module.eks.cluster_version
}

output "eks_oidc_issuer_url" {
  description = "OIDC issuer URL of the GameVault EKS cluster"
  value       = module.eks.oidc_issuer_url
}

output "eks_node_group_name" {
  description = "Name of the GameVault EKS node group"
  value       = module.eks.node_group_name
}



# EKS STORAGE OUTPUTS


output "ebs_csi_driver_addon_name" {
  description = "EBS CSI Driver EKS add-on"
  value       = module.eks.ebs_csi_driver_addon_name
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role used by the EBS CSI Driver"
  value       = module.eks.ebs_csi_driver_role_arn
}



# ECR OUTPUTS

output "ecr_api_repository_name" {
  description = "Name of the GameVault API ECR repository"
  value       = module.ecr.api_repository_name
}

output "ecr_api_repository_arn" {
  description = "ARN of the GameVault API ECR repository"
  value       = module.ecr.api_repository_arn
}

output "ecr_api_repository_url" {
  description = "URL of the GameVault API ECR repository"
  value       = module.ecr.api_repository_url
}

output "ecr_worker_repository_name" {
  description = "Name of the GameVault worker ECR repository"
  value       = module.ecr.worker_repository_name
}

output "ecr_worker_repository_arn" {
  description = "ARN of the GameVault worker ECR repository"
  value       = module.ecr.worker_repository_arn
}

output "ecr_worker_repository_url" {
  description = "URL of the GameVault worker ECR repository"
  value       = module.ecr.worker_repository_url
}





# AWS LOAD BALANCER CONTROLLER OUTPUTS


output "alb_controller_iam_role_arn" {
  description = "IAM role ARN used by the AWS Load Balancer Controller"
  value       = module.alb_controller.iam_role_arn
}

output "alb_controller_iam_role_name" {
  description = "IAM role name used by the AWS Load Balancer Controller"
  value       = module.alb_controller.iam_role_name
}

output "alb_controller_iam_policy_arn" {
  description = "IAM policy ARN used by the AWS Load Balancer Controller"
  value       = module.alb_controller.iam_policy_arn
}

output "alb_controller_oidc_provider_arn" {
  description = "EKS OIDC provider ARN used by the AWS Load Balancer Controller"
  value       = module.alb_controller.oidc_provider_arn
}

output "alb_controller_service_account_name" {
  description = "Kubernetes ServiceAccount used by the AWS Load Balancer Controller"
  value       = module.alb_controller.service_account_name
}

output "alb_controller_helm_release" {
  description = "Helm release name of the AWS Load Balancer Controller"
  value       = module.alb_controller.helm_release_name
}

output "alb_controller_helm_namespace" {
  description = "Kubernetes namespace of the AWS Load Balancer Controller"
  value       = module.alb_controller.helm_release_namespace
}



# GAMEVAULT KUBERNETES OUTPUTS


output "gamevault_namespace" {
  description = "Kubernetes namespace containing GameVault"
  value       = module.gamevault_kubernetes.namespace
}

output "api_deployment_name" {
  description = "Name of the GameVault API Deployment"
  value       = module.gamevault_kubernetes.api_deployment_name
}

output "api_replicas" {
  description = "Configured number of GameVault API replicas"
  value       = module.gamevault_kubernetes.api_replicas
}

output "postgres_service_name" {
  description = "Name of the GameVault PostgreSQL Service"
  value       = module.gamevault_kubernetes.postgres_service_name
}

output "postgres_service_port" {
  description = "Port of the GameVault PostgreSQL Service"
  value       = module.gamevault_kubernetes.postgres_service_port
}

output "postgres_database" {
  description = "GameVault PostgreSQL database name"
  value       = module.gamevault_kubernetes.postgres_database
}

output "postgres_username" {
  description = "GameVault PostgreSQL username"
  value       = module.gamevault_kubernetes.postgres_username
}

output "worker_deployment_name" {
  description = "Name of the GameVault worker Deployment"
  value       = module.gamevault_kubernetes.worker_deployment_name
}

output "worker_replicas" {
  description = "Configured number of GameVault worker replicas"
  value       = module.gamevault_kubernetes.worker_replicas
}

output "api_hpa_name" {
  description = "Name of the GameVault API HPA"
  value       = module.gamevault_kubernetes.api_hpa_name
}

output "worker_hpa_name" {
  description = "Name of the GameVault worker HPA"
  value       = module.gamevault_kubernetes.worker_hpa_name
}

output "service_account_name" {
  description = "Name of the GameVault Kubernetes ServiceAccount"
  value       = module.gamevault_kubernetes.service_account_name
}



# AWS ALB / INGRESS OUTPUTS


output "ingress_name" {
  description = "Name of the GameVault Kubernetes ALB Ingress"
  value       = module.gamevault_kubernetes.ingress_name
}

output "ingress_hostname" {
  description = "Hostname of the AWS Application Load Balancer"
  value       = module.gamevault_kubernetes.ingress_hostname
}

