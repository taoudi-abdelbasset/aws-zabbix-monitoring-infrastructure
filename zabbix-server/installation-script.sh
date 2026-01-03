#!/bin/bash

###############################################################################
# Zabbix Server Installation Script
# Description: Installs Docker, Docker Compose and deploys Zabbix containers
# OS: Ubuntu 22.04 LTS
# Date: January 2026
###############################################################################

set -e  # Exit on any error

echo "======================================"
echo "Zabbix Server Installation Script"
echo "======================================"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo or as root"
    exit 1
fi

echo "[1/7] Updating system packages..."
apt-get update -y

echo "[2/7] Installing prerequisites..."
apt-get install -y ca-certificates curl gnupg lsb-release

echo "[3/7] Adding Docker's official GPG key..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "[4/7] Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[5/7] Installing Docker Engine and Docker Compose..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[6/7] Starting and enabling Docker service..."
systemctl enable docker
systemctl start docker

echo "[7/7] Adding current user to docker group..."
usermod -aG docker ubuntu

echo ""
echo "======================================"
echo "✅ Docker installation completed!"
echo "======================================"
echo ""

# Verify installation
echo "Installed versions:"
docker --version
docker compose version

echo ""
echo "Next steps:"
echo "1. Logout and login again (or run: newgrp docker)"
echo "2. Create a directory: mkdir ~/zabbix-docker && cd ~/zabbix-docker"
echo "3. Create docker-compose.yml file (see repository)"
echo "4. Run: docker compose up -d"
echo "   Note: Use 'docker compose' (with space) not 'docker-compose'"
echo "5. Wait 2-3 minutes for initialization"
echo "6. Check containers: docker compose ps"
echo "7. View logs: docker compose logs -f"
echo "8. Access Zabbix at: http://YOUR_SERVER_IP"
echo ""
echo "Default credentials:"
echo "  Username: Admin"
echo "  Password: zabbix"
echo ""
echo "Troubleshooting:"
echo "  - If docker commands fail, run: newgrp docker"
echo "  - Check Docker status: sudo systemctl status docker"
echo "  - View container logs: docker compose logs zabbix-server"
echo ""