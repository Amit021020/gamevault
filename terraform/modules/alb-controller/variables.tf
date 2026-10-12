variable "eks_cluster_name" {
  type = string
}

variable "eks_oidc_issuer_url" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "environment" {
  type = string
}

variable "iam_role_name" {
  type    = string
  default = "gamevault-aws-load-balancer-controller"
}

variable "kubernetes_namespace" {
  type    = string
  default = "kube-system"
}

variable "kubernetes_service_account" {
  type    = string
  default = "aws-load-balancer-controller"
}

variable "helm_release_name" {
  type    = string
  default = "aws-load-balancer-controller"
}

variable "helm_namespace" {
  type    = string
  default = "kube-system"
}

variable "helm_chart_version" {
  type    = string
  default = "1.14.0"
}