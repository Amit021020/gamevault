output "namespace" {
  description = "GameVault Kubernetes namespace"
  value       = kubernetes_namespace.gamevault.metadata[0].name
}

output "api_service_name" {
  description = "GameVault API Service name"
  value       = kubernetes_service.api.metadata[0].name
}

output "api_service_port" {
  description = "GameVault API Service port"
  value       = kubernetes_service.api.spec[0].port[0].port
}
output "api_deployment_name" {
  description = "Name of the GameVault API Deployment"
  value       = kubernetes_deployment.api.metadata[0].name
}

output "api_replicas" {
  description = "Configured number of GameVault API replicas"
  value       = kubernetes_deployment.api.spec[0].replicas
}
output "postgres_service_name" {
  description = "Name of the PostgreSQL Service"
  value       = kubernetes_service.postgres.metadata[0].name
}

output "postgres_service_port" {
  description = "Port exposed by the PostgreSQL Service"
  value       = kubernetes_service.postgres.spec[0].port[0].port
}

output "postgres_database" {
  description = "GameVault PostgreSQL database name"
  value       = var.postgres_database
}

output "postgres_username" {
  description = "GameVault PostgreSQL username"
  value       = var.postgres_username
}
output "redis_service_name" {
  description = "Name of the Redis Service"
  value       = kubernetes_service.redis.metadata[0].name
}

output "redis_service_port" {
  description = "Port exposed by the Redis Service"
  value       = kubernetes_service.redis.spec[0].port[0].port
}
output "worker_deployment_name" {
  description = "Name of the GameVault worker Deployment"
  value       = kubernetes_deployment.worker.metadata[0].name
}

output "worker_replicas" {
  description = "Configured number of GameVault worker replicas"
  value       = kubernetes_deployment.worker.spec[0].replicas
}

output "api_hpa_name" {
  description = "Name of the GameVault API HPA"
  value       = kubernetes_horizontal_pod_autoscaler_v2.api.metadata[0].name
}

output "worker_hpa_name" {
  description = "Name of the GameVault worker HPA"
  value       = kubernetes_horizontal_pod_autoscaler_v2.worker.metadata[0].name
}

output "service_account_name" {
  description = "Name of the GameVault ServiceAccount"
  value       = kubernetes_service_account.gamevault.metadata[0].name
}
output "ingress_name" {
  description = "GameVault AWS ALB Ingress name"
  value       = kubernetes_ingress_v1.gamevault.metadata[0].name
}

output "ingress_hostname" {
  description = "AWS ALB hostname"
  value = try(
    kubernetes_ingress_v1.gamevault.status[0].load_balancer[0].ingress[0].hostname,
    null
  )
}