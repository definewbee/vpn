provider "aws" {
    region       = var.region
}

#创建 VPC
resource "aws_vpc" "ntt-vpc" {
    cidr_block   = var.vpc_cidr

    tags = {
        Name     = "NTT Main VPC"
    }
}

# 创建公有子网
resource "aws_subnet" "public" {
    vpc_id          = aws_vpc.ntt-vpc.id
    cidr_block      = var.public_subnet_cidr

    tags = {
      Name          = "NTT Public Subnet"
    }
}

# 创建私有子网
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.ntt-vpc.id
  cidr_block        = var.private_subnet_cidr

  tags = {
    Name            = "NTT Private Subnet"
  }
}

#创建 Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id          = aws_vpc.ntt-vpc.id

    tags            = {
        Name        = "NTT igw"
    }
}

# 创建路由表
resource "aws_route_table" "public" {
    vpc_id          = aws_vpc.ntt-vpc.id

    route {
        cidr_block  = "0.0.0.0/0"
        gateway_id  = aws_internet_gateway.igw.id
    }
}

# 关联路由表到公有子网
resource "aws_route_table_association" "public" {
    subnet_id       = aws_subnet.public.id
    route_table_id  = aws_route_table.public.id
}

