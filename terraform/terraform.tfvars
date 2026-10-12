
# General


environment = "dev"


# AWS


aws_region = "ap-south-1"


# VPC / Networking


vpc_name = "gamevault-vpc"
vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "ap-south-1a",
  "ap-south-1b"
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24"
]


# EKS - Amazon Elastic Kubernetes Service


eks_cluster_name       = "gamevault-eks"
eks_kubernetes_version = "1.35"
eks_node_count         = 1
eks_node_instance_type = "t3.small"


# ECR - Amazon Elastic Container Registry


ecr_repository_name = "gamevault-api"


# AWS Load Balancer Controller


alb_name = "gamevault-alb"


# Kubernetes


kubernetes_namespace = "gamevault"

# ------------------------------------------------------------
# GameVault API
# ------------------------------------------------------------

api_service_name = "gamevault-api-service"

api_service_port = 8000
api_target_port  = 8000

api_image = "gamevault-api:latest"

api_replicas       = 3
api_container_port = 8000

api_cpu_request    = "100m"
api_memory_request = "128Mi"

api_cpu_limit    = "500m"
api_memory_limit = "512Mi"

# ------------------------------------------------------------
# PostgreSQL
# ------------------------------------------------------------

postgres_image        = "postgres:15-alpine"
postgres_database     = "gamevault"
postgres_username     = "gamevault"
postgres_password     = "CHANGE_ME"
postgres_port         = 5432
postgres_storage_size = "5Gi"
postgres_service_name = "postgres-gamevault"

# ------------------------------------------------------------
# Redis
# ------------------------------------------------------------

redis_image        = "redis:7-alpine"
redis_service_name = "redis-gamevault"
redis_port         = 6379

# ------------------------------------------------------------
# Worker
# ------------------------------------------------------------

worker_image          = "gamevault-worker:latest"
worker_replicas       = 3
worker_container_port = 8001

worker_cpu_request    = "100m"
worker_memory_request = "128Mi"

worker_cpu_limit    = "500m"
worker_memory_limit = "512Mi"


# Kubernetes HPA


api_hpa_min_replicas = 3
api_hpa_max_replicas = 6
api_hpa_cpu_target   = 70

worker_hpa_min_replicas = 3
worker_hpa_max_replicas = 6
worker_hpa_cpu_target   = 70