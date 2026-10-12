output "api_repository_name" {
  description = "Name of the GameVault API ECR repository"
  value       = aws_ecr_repository.api.name
}

output "api_repository_arn" {
  description = "ARN of the GameVault API ECR repository"
  value       = aws_ecr_repository.api.arn
}

output "api_repository_url" {
  description = "URL used to push and pull the GameVault API image"
  value       = aws_ecr_repository.api.repository_url
}

output "worker_repository_name" {
  description = "Name of the GameVault worker ECR repository"
  value       = aws_ecr_repository.worker.name
}

output "worker_repository_arn" {
  description = "ARN of the GameVault worker ECR repository"
  value       = aws_ecr_repository.worker.arn
}

output "worker_repository_url" {
  description = "URL used to push and pull the GameVault worker image"
  value       = aws_ecr_repository.worker.repository_url
}