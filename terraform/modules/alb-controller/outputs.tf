output "iam_role_arn" {
  description = "IAM role ARN used by the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "iam_role_name" {
  description = "IAM role name used by the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.name
}

output "iam_policy_arn" {
  description = "IAM policy ARN used by the AWS Load Balancer Controller"
  value       = aws_iam_policy.alb_controller.arn
}

output "oidc_provider_arn" {
  description = "EKS IAM OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "service_account_name" {
  description = "Kubernetes service account used by the controller"
  value       = kubernetes_service_account.alb_controller.metadata[0].name
}

output "helm_release_name" {
  description = "AWS Load Balancer Controller Helm release"
  value       = helm_release.alb_controller.name
}

output "helm_release_namespace" {
  description = "Namespace containing the AWS Load Balancer Controller"
  value       = helm_release.alb_controller.namespace
}