resource "kubernetes_namespace" "gamevault" {
  metadata {
    name = var.namespace
  }
}
#API-Deployment
resource "kubernetes_deployment" "api" {
  metadata {
    name      = "gamevault-api"
    namespace = kubernetes_namespace.gamevault.metadata[0].name

    labels = {
      app = "gamevault-api"
    }
  }

  spec {
    replicas = var.api_replicas

    selector {
      match_labels = {
        app = "gamevault-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "gamevault-api"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.gamevault.metadata[0].name
        container {
          name  = "gamevault-api"
          image = var.api_image
          
          env {
            name = "REDIS_QUEUE"

            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.gamevault.metadata[0].name
                key  = "REDIS_QUEUE"
              }
            }
          }

          # PostgreSQL connection settings
          env {
            name  = "DATABASE_HOST"
            value = kubernetes_service.postgres.metadata[0].name
          }

          env {
            name  = "DATABASE_PORT"
            value = "5432"
          }

          env {
            name = "DATABASE_NAME"

            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "POSTGRES_DB"
              }
            }
          }

          env {
            name = "DATABASE_USER"

            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "POSTGRES_USER"
              }
            }
          }

          env {
            name = "DATABASE_PASSWORD"

            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }


          port {
            name           = "http"
            container_port = var.api_container_port
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = var.api_cpu_request
              memory = var.api_memory_request
            }

            limits = {
              cpu    = var.api_cpu_limit
              memory = var.api_memory_limit
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = var.api_container_port
            }

            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 2
            failure_threshold     = 3
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = var.api_container_port
            }

            initial_delay_seconds = 15
            period_seconds        = 20
            timeout_seconds       = 2
            failure_threshold     = 3
          }
        }
      }
    }
  }
}

#API-Service
resource "kubernetes_service" "api" {
  metadata {
    name      = var.api_service_name
    namespace = kubernetes_namespace.gamevault.metadata[0].name

    labels = {
      app = "gamevault-api-service"
    }
  }

  spec {
    selector = {
      app = "gamevault-api"
    }

    port {
      name        = "http"
      port        = var.api_service_port
      target_port = var.api_target_port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}


# GameVault AWS ALB Ingress

resource "kubernetes_ingress_v1" "gamevault" {
  metadata {
    name      = "gamevault-ingress"
    namespace = kubernetes_namespace.gamevault.metadata[0].name

    annotations = {
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"

      "alb.ingress.kubernetes.io/target-type" = "ip"

      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\":80}]"

      "alb.ingress.kubernetes.io/healthcheck-path" = "/health"

      "alb.ingress.kubernetes.io/healthcheck-port" = "traffic-port"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.api.metadata[0].name

              port {
                number = var.api_service_port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service.api
  ]
}
# Redis Deployment

resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis-gamevault"
    namespace = kubernetes_namespace.gamevault.metadata[0].name

    labels = {
      app = "redis-gamevault"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "redis-gamevault"
      }
    }

    template {
      metadata {
        labels = {
          app = "redis-gamevault"
        }
      }

      spec {
        container {
          name  = "redis"
          image = var.redis_image

          port {
            name           = "redis"
            container_port = var.redis_port
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }

            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          readiness_probe {
            exec {
              command = [
                "redis-cli",
                "ping"
              ]
            }

            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          liveness_probe {
            exec {
              command = [
                "redis-cli",
                "ping"
              ]
            }

            initial_delay_seconds = 15
            period_seconds        = 20
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }
      }
    }
  }
}
# Redis Service

resource "kubernetes_service" "redis" {
  metadata {
    name      = var.redis_service_name
    namespace = kubernetes_namespace.gamevault.metadata[0].name

    labels = {
      app = "redis-gamevault"
    }
  }

  spec {
    selector = {
      app = "redis-gamevault"
    }

    port {
      name        = "redis"
      port        = var.redis_port
      target_port = var.redis_port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
# GameVault Worker Deployment

resource "kubernetes_deployment" "worker" {
  metadata {
    name      = "gamevault-worker"
    namespace = kubernetes_namespace.gamevault.metadata[0].name

    labels = {
      app = "gamevault-worker"
    }
  }

  spec {
    replicas = var.worker_replicas

    selector {
      match_labels = {
        app = "gamevault-worker"
      }
    }

    template {
      metadata {
        labels = {
          app = "gamevault-worker"
        }
      }

      spec {
        container {
          name  = "gamevault-worker"
          image = var.worker_image

          env {
            name  = "REDIS_HOST"
            value = var.redis_service_name
          }

          env {
            name  = "REDIS_PORT"
            value = tostring(var.redis_port)
          }

          env {
            name = "REDIS_QUEUE"

            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.gamevault.metadata[0].name
                key  = "REDIS_QUEUE"
              }
            }
          }

          env {
            name  = "POSTGRES_HOST"
            value = var.postgres_host
          }

          env {
            name  = "POSTGRES_PORT"
            value = tostring(var.postgres_port)
          }

          env {
            name = "POSTGRES_DB"

            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "POSTGRES_DB"
              }
            }
          }

          env {
            name = "POSTGRES_USER"

            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "POSTGRES_USER"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"

            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          resources {
            requests = {
              cpu    = var.worker_cpu_request
              memory = var.worker_memory_request
            }

            limits = {
              cpu    = var.worker_cpu_limit
              memory = var.worker_memory_limit
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "postgres-gamevault-secret"
    namespace = kubernetes_namespace.gamevault.metadata[0].name
  }

  type = "Opaque"

  data = {
    POSTGRES_DB       = var.postgres_database
    POSTGRES_USER     = var.postgres_username
    POSTGRES_PASSWORD = var.postgres_password
  }
}
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gamevault-gp3"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  parameters = {
    type = "gp3"
  }
}

resource "kubernetes_persistent_volume_claim" "postgres" {
  metadata {
    name      = "postgres-pvc"
    namespace = kubernetes_namespace.gamevault.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    storage_class_name = "gamevault-gp3"

    resources {
      requests = {
        storage = var.postgres_storage_size
      }
    }
  }
}
resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres-gamevault"
    namespace = kubernetes_namespace.gamevault.metadata[0].name

    labels = {
      app = "postgres-gamevault"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "postgres-gamevault"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres-gamevault"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = var.postgres_image

          port {
            name           = "postgres"
            container_port = var.postgres_port
            protocol       = "TCP"
          }

          env {
            name  = "POSTGRES_HOST"
            value = var.postgres_host
          }

          env {
            name  = "POSTGRES_PORT"
            value = tostring(var.postgres_port)
          }

          env {
            name = "POSTGRES_DB"

            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "POSTGRES_DB"
              }
            }
          }

          env {
            name = "POSTGRES_USER"

            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "POSTGRES_USER"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"

            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }

          readiness_probe {
            exec {
              command = [
                "pg_isready",
                "-U",
                var.postgres_username,
                "-d",
                var.postgres_database
              ]
            }

            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 5
          }

          liveness_probe {
            exec {
              command = [
                "pg_isready",
                "-U",
                var.postgres_username,
                "-d",
                var.postgres_database
              ]
            }

            initial_delay_seconds = 30
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 5
          }
        }

        volume {
          name = "postgres-storage"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres.metadata[0].name
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "postgres" {
  metadata {
    name      = var.postgres_service_name
    namespace = kubernetes_namespace.gamevault.metadata[0].name

    labels = {
      app = "postgres-gamevault"
    }
  }

  spec {
    selector = {
      app = "postgres-gamevault"
    }

    port {
      name        = "postgres"
      port        = var.postgres_port
      target_port = var.postgres_port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
# API Horizontal Pod Autoscaler

resource "kubernetes_horizontal_pod_autoscaler_v2" "api" {
  metadata {
    name      = "gamevault-api-hpa"
    namespace = kubernetes_namespace.gamevault.metadata[0].name
  }

  spec {
    min_replicas = var.api_hpa_min_replicas
    max_replicas = var.api_hpa_max_replicas

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.api.metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = var.api_hpa_cpu_target
        }
      }
    }
  }
}
# Worker Horizontal Pod Autoscaler

resource "kubernetes_horizontal_pod_autoscaler_v2" "worker" {
  metadata {
    name      = "gamevault-worker-hpa"
    namespace = kubernetes_namespace.gamevault.metadata[0].name
  }

  spec {
    min_replicas = var.worker_hpa_min_replicas
    max_replicas = var.worker_hpa_max_replicas

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.worker.metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = var.worker_hpa_cpu_target
        }
      }
    }
  }
}
# GameVault Application ConfigMap

resource "kubernetes_config_map" "gamevault" {
  metadata {
    name      = "gamevault-config"
    namespace = kubernetes_namespace.gamevault.metadata[0].name
  }

  data = {
    REDIS_QUEUE = "gamevault_queue"
  }
}
# GameVault Service Account

resource "kubernetes_service_account" "gamevault" {
  metadata {
    name      = "gamevault-service-account"
    namespace = kubernetes_namespace.gamevault.metadata[0].name
  }
}

# GameVault Kubernetes Role

resource "kubernetes_role" "gamevault" {
  metadata {
    name      = "gamevault-role"
    namespace = kubernetes_namespace.gamevault.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }
}

# GameVault Role Binding

resource "kubernetes_role_binding" "gamevault" {
  metadata {
    name      = "gamevault-role-binding"
    namespace = kubernetes_namespace.gamevault.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.gamevault.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.gamevault.metadata[0].name
    namespace = kubernetes_namespace.gamevault.metadata[0].name
  }
}
# PostgreSQL Network Policy

resource "kubernetes_network_policy" "postgres" {
  metadata {
    name      = "postgres-network-policy"
    namespace = kubernetes_namespace.gamevault.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "postgres-gamevault"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "gamevault-api"
          }
        }
      }

      from {
        pod_selector {
          match_labels = {
            app = "gamevault-worker"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = var.postgres_port
      }
    }
  }
}
# Redis Network Policy

resource "kubernetes_network_policy" "redis" {
  metadata {
    name      = "redis-network-policy"
    namespace = kubernetes_namespace.gamevault.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "redis-gamevault"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "gamevault-api"
          }
        }
      }

      from {
        pod_selector {
          match_labels = {
            app = "gamevault-worker"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = var.redis_port
      }
    }
  }
}