
# AWS


variable "aws_region" {
  description = "AWS region where GameVault will be deployed"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}



# VPC / NETWORK


variable "vpc_name" {
  description = "Name of the GameVault VPC"
  type        = string
  default     = "gamevault-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the GameVault VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones used by GameVault"
  type        = list(string)

  default = [
    "ap-south-1a",
    "ap-south-1b"
  ]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)

  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)

  default = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]
}



# EKS


variable "eks_cluster_name" {
  description = "Name of the GameVault EKS cluster"
  type        = string
  default     = "gamevault-eks"
}

variable "eks_kubernetes_version" {
  description = "Kubernetes version for the GameVault EKS cluster"
  type        = string
  default     = "1.35"
}

variable "eks_node_count" {
  description = "Number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_instance_type" {
  description = "EC2 instance type used by EKS worker nodes"
  type        = string
  default     = "t3.small"
}



# ECR


variable "ecr_repository_name" {
  description = "ECR repository for the GameVault API"
  type        = string
  default     = "gamevault-api"
}



# AWS LOAD BALANCER CONTROLLER


variable "alb_name" {
  description = "Name of the GameVault AWS Application Load Balancer"
  type        = string
  default     = "gamevault-alb"
}



# KUBERNETES


variable "kubernetes_namespace" {
  description = "Kubernetes namespace for GameVault"
  type        = string
  default     = "gamevault"
}



# GAMEVAULT API


variable "api_service_name" {
  description = "Kubernetes service name for the GameVault API"
  type        = string
  default     = "gamevault-api-service"
}

variable "api_service_port" {
  description = "Kubernetes service port for the GameVault API"
  type        = number
  default     = 8000
}

variable "api_target_port" {
  description = "Container target port for the GameVault API"
  type        = number
  default     = 8000
}

variable "api_image" {
  description = "Container image for the GameVault API"
  type        = string
  default     = "gamevault-api:latest"
}

variable "api_replicas" {
  description = "Initial number of GameVault API replicas"
  type        = number
  default     = 3
}

variable "api_container_port" {
  description = "Container port used by the GameVault API"
  type        = number
  default     = 8000
}

variable "api_cpu_request" {
  description = "CPU request for the GameVault API"
  type        = string
  default     = "100m"
}

variable "api_memory_request" {
  description = "Memory request for the GameVault API"
  type        = string
  default     = "128Mi"
}

variable "api_cpu_limit" {
  description = "CPU limit for the GameVault API"
  type        = string
  default     = "500m"
}

variable "api_memory_limit" {
  description = "Memory limit for the GameVault API"
  type        = string
  default     = "512Mi"
}



# POSTGRESQL


variable "postgres_image" {
  description = "PostgreSQL container image"
  type        = string
  default     = "postgres:15-alpine"
}

variable "postgres_database" {
  description = "PostgreSQL database name"
  type        = string
  default     = "gamevault"
}

variable "postgres_username" {
  description = "PostgreSQL username"
  type        = string
  default     = "gamevault"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "postgres_port" {
  description = "PostgreSQL service port"
  type        = number
  default     = 5432
}

variable "postgres_storage_size" {
  description = "PostgreSQL persistent storage size"
  type        = string
  default     = "5Gi"
}

variable "postgres_service_name" {
  description = "Kubernetes service name for PostgreSQL"
  type        = string
  default     = "postgres-gamevault"
}



# REDIS


variable "redis_image" {
  description = "Redis container image"
  type        = string
  default     = "redis:7-alpine"
}

variable "redis_service_name" {
  description = "Kubernetes service name for Redis"
  type        = string
  default     = "redis-gamevault"
}

variable "redis_port" {
  description = "Redis service port"
  type        = number
  default     = 6379
}



# WORKER


variable "worker_image" {
  description = "Container image for the GameVault worker"
  type        = string
  default     = "gamevault-worker:latest"
}

variable "worker_replicas" {
  description = "Initial number of GameVault worker replicas"
  type        = number
  default     = 3
}

variable "worker_container_port" {
  description = "Container port used by the GameVault worker"
  type        = number
  default     = 8001
}

variable "worker_cpu_request" {
  description = "CPU request for the GameVault worker"
  type        = string
  default     = "100m"
}

variable "worker_memory_request" {
  description = "Memory request for the GameVault worker"
  type        = string
  default     = "128Mi"
}

variable "worker_cpu_limit" {
  description = "CPU limit for the GameVault worker"
  type        = string
  default     = "500m"
}

variable "worker_memory_limit" {
  description = "Memory limit for the GameVault worker"
  type        = string
  default     = "512Mi"
}



# KUBERNETES HPA


variable "api_hpa_min_replicas" {
  description = "Minimum API replicas for HPA"
  type        = number
  default     = 3
}

variable "api_hpa_max_replicas" {
  description = "Maximum API replicas for HPA"
  type        = number
  default     = 6
}

variable "api_hpa_cpu_target" {
  description = "Target CPU utilization for API HPA"
  type        = number
  default     = 70
}

variable "worker_hpa_min_replicas" {
  description = "Minimum worker replicas for HPA"
  type        = number
  default     = 3
}

variable "worker_hpa_max_replicas" {
  description = "Maximum worker replicas for HPA"
  type        = number
  default     = 6
}

variable "worker_hpa_cpu_target" {
  description = "Target CPU utilization for worker HPA"
  type        = number
  default     = 70
}