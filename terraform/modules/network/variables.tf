variable "vpc_name" {
  description = "Name of the GameVault VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the GameVault VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by GameVault"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)

  validation {
    condition = length(var.public_subnet_cidrs) == length(var.availability_zones)

    error_message = "The number of public subnet CIDRs must match the number of availability zones."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)

  validation {
    condition = length(var.private_subnet_cidrs) == length(var.availability_zones)

    error_message = "The number of private subnet CIDRs must match the number of availability zones."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}