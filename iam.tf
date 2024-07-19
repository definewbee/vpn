# 创建 IAM 角色
resource "aws_iam_role" "vpn_role" {
  name = "vpn_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 创建 IAM 角色用于 VPC 流日志
resource "aws_iam_role" "flow_log" {
  name = "vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

# 创建 IAM 实例配置文件
resource "aws_iam_instance_profile" "vpn_profile" {
  name = "vpn_profile"
  role = aws_iam_role.vpn_role.name
}

# 创建自定义 IAM 策略
resource "aws_iam_policy" "vpn_policy" {
  name        = "vpn_policy"
  path        = "/"
  description = "IAM policy for VPN server"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = aws_s3_bucket.vpn_bucket.arn 
      }
    ]
  })
}

# 附加 IAM 策略到 VPC 流日志角色
resource "aws_iam_role_policy" "flow_log" {
  name = "vpc-flow-log-policy"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# 将自定义策略附加到 IAM 角色
resource "aws_iam_role_policy_attachment" "vpn_policy_attach" {
  role       = aws_iam_role.vpn_role.name
  policy_arn = aws_iam_policy.vpn_policy.arn
}