data "aws_caller_identity" "current" {}

data "tls_certificate" "eks" {
  url = var.eks_oidc_issuer_url
}

data "aws_iam_policy_document" "alb_controller_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.eks.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_issuer_url, "https://", "")}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${var.kubernetes_namespace}:${var.kubernetes_service_account}"
      ]
    }
  }
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = var.eks_oidc_issuer_url

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.eks.certificates[0].sha1_fingerprint
  ]
}

resource "aws_iam_policy" "alb_controller" {
  name        = "GameVaultAWSLoadBalancerControllerPolicy"
  description = "IAM policy for the AWS Load Balancer Controller"

  policy = file("${path.module}/iam_policy.json")

  tags = {
    Environment = var.environment
    Project     = "GameVault"
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json

  tags = {
    Environment = var.environment
    Project     = "GameVault"
  }
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = var.kubernetes_service_account
    namespace = var.kubernetes_namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.alb_controller
  ]
}

resource "helm_release" "alb_controller" {
  name = var.helm_release_name

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.helm_chart_version

  namespace        = var.helm_namespace
  create_namespace = true

  set {
    name  = "clusterName"
    value = var.eks_cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = var.kubernetes_service_account
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [
    kubernetes_service_account.alb_controller
  ]
}