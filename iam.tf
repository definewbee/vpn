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

# 创建IAM实例配置文件
resource "aws_iam_instance_profile" "vpn_profile" {
  name = "vpn_profile"
  role = aws_iam_role.vpn_role.name
}

# 附加策略到IAM角色
resource "aws_iam_role_policy_attachment" "vpn_attach" {
  role       = aws_iam_role.vpn_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"  # 根据需求调整权限
}