variable "namespace" {
  description = "Kubernetes namespace for GameVault"
  type        = string
}

variable "api_service_name" {
  description = "Name of the GameVault API Service"
  type        = string
}

variable "api_service_port" {
  description = "Port exposed by the GameVault API Service"
  type        = number
}

variable "api_target_port" {
  description = "Container port targeted by the GameVault API Service"
  type        = number
}
variable "api_image" {
  description = "Container image used by the GameVault API"
  type        = string
}

variable "api_replicas" {
  description = "Number of GameVault API replicas"
  type        = number
  default     = 3
}

variable "api_container_port" {
  description = "Container port used by the GameVault API"
  type        = number
  default     = 8000
}

variable "api_cpu_request" {
  description = "CPU request for each GameVault API pod"
  type        = string
  default     = "100m"
}

variable "api_memory_request" {
  description = "Memory request for each GameVault API pod"
  type        = string
  default     = "128Mi"
}

variable "api_cpu_limit" {
  description = "CPU limit for each GameVault API pod"
  type        = string
  default     = "500m"
}

variable "api_memory_limit" {
  description = "Memory limit for each GameVault API pod"
  type        = string
  default     = "512Mi"
}
variable "postgres_image" {
  description = "Container image used by PostgreSQL"
  type        = string
  default     = "postgres:15-alpine"
}

variable "postgres_database" {
  description = "GameVault PostgreSQL database name"
  type        = string
  default     = "gamevault"
}

variable "postgres_username" {
  description = "GameVault PostgreSQL username"
  type        = string
  default     = "gamevault"
}

variable "postgres_password" {
  description = "GameVault PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "postgres_storage_size" {
  description = "Persistent storage requested by PostgreSQL"
  type        = string
  default     = "5Gi"
}

variable "postgres_service_name" {
  description = "Kubernetes Service name for PostgreSQL"
  type        = string
  default     = "postgres-gamevault"
}
variable "postgres_host" {
  description = "Hostname of the PostgreSQL Service"
  type        = string
}
# Redis

variable "redis_image" {
  description = "Docker image used by Redis"
  type        = string
  default     = "redis:7-alpine"
}

variable "redis_service_name" {
  description = "Kubernetes Service name for Redis"
  type        = string
  default     = "redis-gamevault"
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

# Worker

variable "worker_image" {
  description = "Docker image used by the GameVault worker"
  type        = string
  default     = "gamevault-worker:latest"
}

variable "worker_replicas" {
  description = "Number of GameVault worker replicas"
  type        = number
  default     = 3
}

variable "worker_container_port" {
  description = "Container port used by the worker"
  type        = number
  default     = 8001
}

variable "worker_cpu_request" {
  description = "CPU request for each worker pod"
  type        = string
  default     = "100m"
}

variable "worker_memory_request" {
  description = "Memory request for each worker pod"
  type        = string
  default     = "128Mi"
}

variable "worker_cpu_limit" {
  description = "CPU limit for each worker pod"
  type        = string
  default     = "500m"
}

variable "worker_memory_limit" {
  description = "Memory limit for each worker pod"
  type        = string
  default     = "512Mi"
}
# Kubernetes HPA

variable "api_hpa_min_replicas" {
  description = "Minimum number of API replicas"
  type        = number
  default     = 3
}

variable "api_hpa_max_replicas" {
  description = "Maximum number of API replicas"
  type        = number
  default     = 6
}

variable "api_hpa_cpu_target" {
  description = "Target average CPU utilization for API HPA"
  type        = number
  default     = 70
}

variable "worker_hpa_min_replicas" {
  description = "Minimum number of worker replicas"
  type        = number
  default     = 3
}

variable "worker_hpa_max_replicas" {
  description = "Maximum number of worker replicas"
  type        = number
  default     = 6
}

variable "worker_hpa_cpu_target" {
  description = "Target average CPU utilization for worker HPA"
  type        = number
  default     = 70
}