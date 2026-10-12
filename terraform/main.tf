provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"

    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"

      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}



# Network


module "network" {
  source = "./modules/network"

  vpc_name             = var.vpc_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = var.environment
}



# ECR


module "ecr" {
  source = "./modules/ecr"

  project_name = "gamevault"
  environment  = var.environment
}


# EKS


module "eks" {
  source = "./modules/eks"

  cluster_name       = var.eks_cluster_name
  kubernetes_version = var.eks_kubernetes_version

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  node_count         = var.eks_node_count
  node_instance_type = var.eks_node_instance_type

  environment = var.environment
}



# AWS Load Balancer Controller

module "alb_controller" {
  source = "./modules/alb-controller"

  eks_cluster_name    = module.eks.cluster_name
  eks_oidc_issuer_url = module.eks.oidc_issuer_url

  vpc_id      = module.network.vpc_id
  aws_region  = var.aws_region
  environment = var.environment

  iam_role_name = "gamevault-aws-load-balancer-controller"

  kubernetes_namespace       = "kube-system"
  kubernetes_service_account = "aws-load-balancer-controller"

  helm_release_name  = "aws-load-balancer-controller"
  helm_namespace     = "kube-system"
  helm_chart_version = "1.14.0"
}



# GameVault Kubernetes


module "gamevault_kubernetes" {
  source = "./modules/gamevault-kubernetes"

  namespace = var.kubernetes_namespace

  api_service_name = var.api_service_name
  api_service_port = var.api_service_port
  api_target_port  = var.api_target_port

  api_image          = "${module.ecr.api_repository_url}:latest"
  api_replicas       = var.api_replicas
  api_container_port = var.api_container_port

  api_cpu_request       = var.api_cpu_request
  api_memory_request    = var.api_memory_request
  api_cpu_limit         = var.api_cpu_limit
  api_memory_limit      = var.api_memory_limit
  postgres_host         = var.postgres_service_name
  postgres_image        = var.postgres_image
  postgres_database     = var.postgres_database
  postgres_username     = var.postgres_username
  postgres_password     = var.postgres_password
  postgres_port         = var.postgres_port
  postgres_storage_size = var.postgres_storage_size
  postgres_service_name = var.postgres_service_name

  redis_image        = var.redis_image
  redis_service_name = var.redis_service_name
  redis_port         = var.redis_port

  worker_image          = "${module.ecr.worker_repository_url}:latest"
  worker_replicas       = var.worker_replicas
  worker_container_port = var.worker_container_port

  worker_cpu_request    = var.worker_cpu_request
  worker_memory_request = var.worker_memory_request
  worker_cpu_limit      = var.worker_cpu_limit
  worker_memory_limit   = var.worker_memory_limit

  api_hpa_min_replicas = var.api_hpa_min_replicas
  api_hpa_max_replicas = var.api_hpa_max_replicas
  api_hpa_cpu_target   = var.api_hpa_cpu_target

  worker_hpa_min_replicas = var.worker_hpa_min_replicas
  worker_hpa_max_replicas = var.worker_hpa_max_replicas
  worker_hpa_cpu_target   = var.worker_hpa_cpu_target

  depends_on = [
    module.eks,
    module.alb_controller
  ]
}