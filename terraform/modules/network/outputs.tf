output "vpc_id" {
  description = "ID of the GameVault VPC"
  value       = aws_vpc.gamevault.id
}

output "vpc_cidr" {
  description = "CIDR block of the GameVault VPC"
  value       = aws_vpc.gamevault.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.gamevault.id
}

output "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer"
  value       = aws_security_group.alb.id
}