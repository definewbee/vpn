provider "aws" {
    region       = var.region
}

#创建 VPC
resource "aws_vpc" "ntt-vpc" {
    cidr_block              = var.vpc_cidr
    enable_dns_hostnames    = true
    enable_dns_support      = true

    tags = {
        Name                = "NTT Main VPC"
    }
}

# 获取可用区信息
data "aws_availability_zones" "available" {
  state = "available"
}

# 创建公有子网
resource "aws_subnet" "public" {
    count           = length(var.public_subnet_cidrs)
    vpc_id          = aws_vpc.ntt-vpc.id
    cidr_block      = var.public_subnet_cidrs[count.index]
    availability_zone = data.aws_availability_zones.available.names[count.index]

    tags = {
      Name          = "NTT Public Subnet ${count.index + 1}"
    }
}

# 创建私有子网
resource "aws_subnet" "private" {
    count           = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.ntt-vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name            = "NTT Private Subnet ${count.index + 1}"
  }
}

# 创建 Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id          = aws_vpc.ntt-vpc.id

    tags            = {
        Name        = "NTT igw"
    }
}

# 创建NAT Gateway
resource "aws_nat_gateway" "nat" {
    count           = 1
    subnet_id       = aws_subnet.public[count.index].id
    allocation_id   = aws_eip.nat[count.index].id

    tags = {
        Name        = "NTT NAT Gateway"
    }
}

# 为 NAT Gateway 分配弹性 IP
resource "aws_eip" "nat" {
  count = 1
  vpc   = true

  tags = {
    Name = "NAT Gateway EIP"
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

# 创建私有路由表
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.ntt-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[0].id
  }

  tags = {
    Name = "Private Route Table ${count.index + 1}"
  }
}

# 关联路由表到公有子网
resource "aws_route_table_association" "public" {
    count           = 2
    subnet_id       = aws_subnet.public[count.index].id
    route_table_id  = aws_route_table.public.id
}

# 关联私有子网到私有路由表
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# 创建 S3 桶
resource "aws_s3_bucket" "vpn_bucket" {
  bucket = "vpn-config-logs-${random_id.bucket_suffix.hex}"  # 使用随机后缀确保唯一性
  force_destroy = true  # 允许 Terraform 删除非空桶，仅用于测试环境

  tags = {
    Name = "VPN Config and Logs Bucket"
  }
}

# 生成随机后缀
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# 为 S3 桶启用服务器端加密
resource "aws_s3_bucket_server_side_encryption_configuration" "vpn_bucket_encryption" {
  bucket = aws_s3_bucket.vpn_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 阻止公共访问
resource "aws_s3_bucket_public_access_block" "vpn_bucket_public_access_block" {
  bucket = aws_s3_bucket.vpn_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 创建 VPC 流日志
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.ntt-vpc.id
}

# 创建 CloudWatch 日志组用于 VPC 流日志
resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/flow-log"
  retention_in_days = 30
}