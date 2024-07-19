#!/usr/bin/env python3

import os
import subprocess
import argparse
import paramiko
from scp import SCPClient

# OpenVPN服务器配置
SERVER_IP ="13.215.203.112"
SERVER_USER = "ubuntu"
SERVER_KEY_PATH = "vpn-key.pem"

# OpenVPN配置路径
EASYRSA_DIR = "/etc/openvpn/easy-rsa"
OUTPUT_DIR = "/etc/openvpn/client-configs"

def generate_client_config(client_name, overwrite=False):
    """在服务器上生成客户端配置"""
    overwrite_flag = "--force" if overwrite else ""
    commands = [
        f"cd {EASYRSA_DIR}",
        f"sudo -S ./easyrsa build-client-full {client_name} nopass {overwrite_flag}",
        f"sudo -S mkdir -p {OUTPUT_DIR}",
        f"""sudo bash -c 'cat > {OUTPUT_DIR}/{client_name}.ovpn << EOL
client
dev tun
proto udp
remote {SERVER_IP} 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
auth SHA256
key-direction 1
compress lz4-v2
verb 3

<ca>
$(sudo cat {EASYRSA_DIR}/pki/ca.crt)
</ca>
<cert>
$(sudo cat {EASYRSA_DIR}/pki/issued/{client_name}.crt)
</cert>
<key>
$(sudo cat {EASYRSA_DIR}/pki/private/{client_name}.key)
</key>
<tls-auth>
$(sudo cat /etc/openvpn/ta.key)
</tls-auth>
EOL'"""
    ]
    
    return " && ".join(commands)

def run_remote_command(command):
    """在远程服务器上运行命令"""
    key = paramiko.RSAKey.from_private_key_file(SERVER_KEY_PATH)
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(hostname=SERVER_IP, username=SERVER_USER, pkey=key)
        stdin, stdout, stderr = client.exec_command(command)
        print(stdout.read().decode())
        print(stderr.read().decode())
    finally:
        client.close()

def download_config(client_name, local_path):
    """从服务器下载配置文件"""
    key = paramiko.RSAKey.from_private_key_file(SERVER_KEY_PATH)
    with paramiko.SSHClient() as ssh:
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(hostname=SERVER_IP, username=SERVER_USER, pkey=key)
        
        # 检查文件是否存在
        stdin, stdout, stderr = ssh.exec_command(f"sudo test -f {OUTPUT_DIR}/{client_name}.ovpn && echo exists")
        if stdout.read().decode().strip() != "exists":
            print(f"Error: Configuration file for {client_name} does not exist on the server.")
            return False

        with SCPClient(ssh.get_transport()) as scp:
            remote_path = f"{OUTPUT_DIR}/{client_name}.ovpn"
            # 首先复制文件到一个临时位置，以便非root用户可以读取
            ssh.exec_command(f"sudo cp {remote_path} /tmp/{client_name}.ovpn && sudo chmod 644 /tmp/{client_name}.ovpn")
            scp.get(f"/tmp/{client_name}.ovpn", local_path)
            # 清理临时文件
            ssh.exec_command(f"sudo rm /tmp/{client_name}.ovpn")
    return True

def main():
    parser = argparse.ArgumentParser(description="Generate and download OpenVPN client config")
    parser.add_argument("client_name", help="Name of the client")
    parser.add_argument("--output", default=".", help="Local directory to save the config file")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite existing client certificate")
    args = parser.parse_args()

    print(f"Generating config for client: {args.client_name}")
    command = generate_client_config(args.client_name, args.overwrite)
    run_remote_command(command)

    local_path = os.path.join(args.output, f"{args.client_name}.ovpn")
    print(f"Downloading config file to: {local_path}")
    if download_config(args.client_name, local_path):
        print("Client configuration generated and downloaded successfully!")
    else:
        print("Failed to download client configuration.")

if __name__ == "__main__":
    main()