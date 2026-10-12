
# VPC


resource "aws_vpc" "gamevault" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = var.vpc_name
    Environment = var.environment
    Project     = "GameVault"
  }
}



# Internet Gateway


resource "aws_internet_gateway" "gamevault" {
  vpc_id = aws_vpc.gamevault.id

  tags = {
    Name        = "${var.vpc_name}-igw"
    Environment = var.environment
    Project     = "GameVault"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.vpc_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.vpc_name}-nat"
  }

  depends_on = [aws_internet_gateway.gamevault]
}

# Public Subnets
# Used by the Application Load Balancer


resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.gamevault.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.vpc_name}-public-${count.index + 1}"
    Environment = var.environment
    Project     = "GameVault"

    "kubernetes.io/role/elb" = "1"
  }
}



# Private Subnets
# Used by EKS worker nodes


resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.gamevault.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.vpc_name}-private-${count.index + 1}"
    Environment = var.environment
    Project     = "GameVault"

    "kubernetes.io/role/internal-elb" = "1"
  }
}



# Public Route Table


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.gamevault.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gamevault.id
  }

  tags = {
    Name        = "${var.vpc_name}-public-rt"
    Environment = var.environment
    Project     = "GameVault"
  }
}



# Public Route Table Associations


resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}



# Private Route Table


resource "aws_route_table" "private" {
  vpc_id = aws_vpc.gamevault.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = {
    Name        = "${var.vpc_name}-private-rt"
    Environment = var.environment
    Project     = "GameVault"
  }
}



# Private Route Table Associations


resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}



# Security Group for Application Load Balancer


resource "aws_security_group" "alb" {
  name        = "${var.vpc_name}-alb-sg"
  description = "Security group for GameVault Application Load Balancer"
  vpc_id      = aws_vpc.gamevault.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.vpc_name}-alb-sg"
    Environment = var.environment
    Project     = "GameVault"
  }
}