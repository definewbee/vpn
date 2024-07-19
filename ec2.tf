# 创建密钥对
resource "aws_key_pair" "vpn_key" {
  key_name   = "vpn-key"
  public_key = file("${path.module}/vpn-key.pub")
}

resource "aws_instance" "vpn" {
    count                       = length(var.public_subnet_cidrs)
    ami                         = "ami-060e277c0d4cce553" #ubuntu 22.04 TLS
    instance_type               = "t2.medium"
    subnet_id                   = aws_subnet.public[count.index].id
    vpc_security_group_ids      = [aws_security_group.vpn.id]
    associate_public_ip_address = true
    key_name                    = aws_key_pair.vpn_key.key_name

    user_data = <<-EOF
              #!/bin/bash
              set -e

              # 设置日志文件
              LOG_FILE="/var/log/vpn_setup.log"

              # 函数：记录日志
              log() {
                echo "$(date): $1" >> $LOG_FILE
              }

              log "Script started"

              # 更新系统并安装必要的包
              log "Updating system and installing packages"
              apt-get update
              apt-get upgrade -y
              apt-get install -y openvpn easy-rsa
              log "Packages installed"

              # 配置 Easy-RSA
              log "Configuring Easy-RSA"
              make-cadir /etc/openvpn/easy-rsa
              cd /etc/openvpn/easy-rsa
              log "Changed directory to /etc/openvpn/easy-rsa"

              # 设置 Easy-RSA 变量
              cat > vars <<EOV
              set_var EASYRSA_REQ_COUNTRY    "US"
              set_var EASYRSA_REQ_PROVINCE   "California"
              set_var EASYRSA_REQ_CITY       "San Francisco"
              set_var EASYRSA_REQ_ORG        "My Organization"
              set_var EASYRSA_REQ_EMAIL      "admin@example.com"
              set_var EASYRSA_REQ_OU         "My Organizational Unit"
              set_var EASYRSA_BATCH          "1"
              EOV

              # 初始化 PKI
              log "Initializing PKI"
              ./easyrsa init-pki
              log "PKI initialized"

              # 创建 CA
              log "Creating CA"
              ./easyrsa build-ca nopass
              log "CA created"

              # 创建服务器证书和密钥
              log "Creating server certificate and key"
              ./easyrsa build-server-full server nopass
              log "Server certificate and key created"

              # 创建 DH 参数
              log "Creating DH parameters"
              ./easyrsa gen-dh
              log "DH parameters created"

              # 创建 TLS 认证密钥
              log "Creating TLS auth key"
              openvpn --genkey --secret /etc/openvpn/ta.key
              log "TLS auth key created"

              # 复制必要的文件到 OpenVPN 目录
              log "Copying files to OpenVPN directory"
              cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/dh.pem /etc/openvpn/
              log "Files copied"

              # 配置 OpenVPN 服务器
              log "Configuring OpenVPN server"
              cat > /etc/openvpn/server.conf <<EOT
              port 1194
              proto udp
              dev tun
              ca ca.crt
              cert server.crt
              key server.key
              dh dh.pem
              server 10.8.0.0 255.255.255.0
              push "redirect-gateway def1 bypass-dhcp"
              push "dhcp-option DNS 8.8.8.8"
              push "dhcp-option DNS 8.8.4.4"
              keepalive 10 120
              tls-auth ta.key 0
              cipher AES-256-CBC
              auth SHA256
              compress lz4-v2
              push "compress lz4-v2"
              user nobody
              group nogroup
              persist-key
              persist-tun
              status /var/log/openvpn/openvpn-status.log
              log-append  /var/log/openvpn/openvpn.log
              verb 3
              EOT
              log "OpenVPN server configured"

              # 创建日志目录
              mkdir -p /var/log/openvpn
              log "Log directory created"

              # 启用 IP 转发
              echo 1 > /proc/sys/net/ipv4/ip_forward
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
              log "IP forwarding enabled"

              # 配置 NAT
              iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
              echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
              echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
              apt-get install -y iptables-persistent
              log "NAT configured"

              # 启动 OpenVPN 服务
              systemctl start openvpn@server
              systemctl enable openvpn@server
              log "OpenVPN service started and enabled"

              # 设置正确的权限
              chown -R ubuntu:ubuntu /etc/openvpn
              chmod -R 600 /etc/openvpn/easy-rsa/pki
              log "Permissions set"

              log "Script completed"
              EOF

    tags = {
        Name                    = "OpenVPN Server"
    }
}

resource "aws_instance" "private" {
    count                       = length(var.private_subnet_cidrs)
    ami                         = "ami-060e277c0d4cce553"
    instance_type               = "t2.medium"
    subnet_id                   = aws_subnet.private[count.index].id

    tags = {
        Name                    = "Private Instance"
    }
}


# sudo cat /var/log/vpn_setup.log
# sudo cat /var/log/cloud-init-output.log