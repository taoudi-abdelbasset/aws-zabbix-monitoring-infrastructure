#!/bin/bash

###############################################################################
# Zabbix Agent 2 Installation Script for Linux (Ubuntu 22.04)
# Description: Installs and configures Zabbix Agent 2 on Ubuntu
# Usage: sudo ./install-agent.sh <ZABBIX_SERVER_IP> <HOSTNAME>
# Example: sudo ./install-agent.sh ZABBIX_SERVER_PRIVATE_IP Linux-Client-machine
###############################################################################

set -e  # Exit on any error

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: sudo $0 <ZABBIX_SERVER_IP> <HOSTNAME>"
    echo "Example: sudo $0 ZABBIX_SERVER_PRIVATE_IP Linux-Client-machine"
    exit 1
fi

ZABBIX_SERVER_IP=$1
AGENT_HOSTNAME=$2

echo "======================================"
echo "Zabbix Agent 2 Installation Script"
echo "======================================"
echo "Zabbix Server IP: $ZABBIX_SERVER_IP"
echo "Agent Hostname: $AGENT_HOSTNAME"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo or as root"
    exit 1
fi

echo "[1/6] Downloading Zabbix repository package..."
wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu22.04_all.deb

echo "[2/6] Installing Zabbix repository..."
dpkg -i zabbix-release_6.4-1+ubuntu22.04_all.deb

echo "[3/6] Updating package list..."
apt update

echo "[4/6] Installing Zabbix Agent 2..."
apt install -y zabbix-agent2

echo "[5/6] Configuring Zabbix Agent..."
# Backup original config
cp /etc/zabbix/zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf.backup

# Update configuration
sed -i "s/^Server=.*/Server=$ZABBIX_SERVER_IP/" /etc/zabbix/zabbix_agent2.conf
sed -i "s/^ServerActive=.*/ServerActive=$ZABBIX_SERVER_IP/" /etc/zabbix/zabbix_agent2.conf
sed -i "s/^Hostname=.*/Hostname=$AGENT_HOSTNAME/" /etc/zabbix/zabbix_agent2.conf

echo "[6/6] Starting Zabbix Agent service..."
systemctl restart zabbix-agent2
systemctl enable zabbix-agent2

echo ""
echo "======================================"
echo "✅ Zabbix Agent 2 installation completed!"
echo "======================================"
echo ""

# Check agent status
echo "Agent Status:"
systemctl status zabbix-agent2 --no-pager | head -n 10

echo ""
echo "Configuration:"
echo "  Server: $ZABBIX_SERVER_IP"
echo "  ServerActive: $ZABBIX_SERVER_IP"
echo "  Hostname: $AGENT_HOSTNAME"
echo ""
echo "Next steps:"
echo "1. Add this host to Zabbix web interface:"
echo "   - Go to Configuration > Hosts > Create host"
echo "   - Hostname: $AGENT_HOSTNAME"
echo "   - IP address: $(hostname -I | awk '{print $1}')"
echo "   - Add template: 'Linux by Zabbix agent'"
echo ""
echo "2. Wait 1-2 minutes and check the ZBX status turns GREEN"
echo ""
echo "Troubleshooting:"
echo "  View logs: sudo tail -f /var/log/zabbix/zabbix_agent2.log"
echo "  Check status: sudo systemctl status zabbix-agent2"
echo "  Restart agent: sudo systemctl restart zabbix-agent2"
echo ""