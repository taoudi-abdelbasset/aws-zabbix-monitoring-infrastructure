# Installation Guide - AWS Zabbix Monitoring Infrastructure

This guide provides detailed step-by-step instructions for deploying the complete Zabbix monitoring infrastructure on AWS.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [AWS Infrastructure Setup](#aws-infrastructure-setup)
3. [Zabbix Server Installation](#zabbix-server-installation)
4. [Linux Agent Installation](#linux-agent-installation)
5. [Windows Agent Installation](#windows-agent-installation)
6. [Adding Hosts to Zabbix](#adding-hosts-to-zabbix)
7. [Verification](#verification)
8. [Post-Installation](#post-installation)

---

## Prerequisites

### Required Tools

```bash
# AWS CLI (for exporting configurations)
aws --version
# If not installed: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

# Configure AWS CLI
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)

# Optional: jq for JSON parsing
sudo apt install jq  # Ubuntu/Debian
sudo yum install jq  # Amazon Linux/RHEL
```

### AWS Requirements

- **AWS Account** with EC2, VPC permissions
- **SSH Key Pair** created in your target region
- **Your Public IP Address** (find it at https://whatismyipaddress.com/)

---

## AWS Infrastructure Setup

### Overview

For complete infrastructure documentation including detailed network architecture, security group configurations, and network diagrams, see:

**📖 [Complete Infrastructure Documentation](../aws-infrastructure/infra.md)**

The infrastructure documentation includes:
- Detailed VPC and subnet configuration
- Security group rules with traffic flow diagrams
- Network architecture with Mermaid diagrams
- Route table configurations
- Internet Gateway setup
- Network ACL settings

### Quick Setup Guide

This section provides the essential CLI commands for rapid deployment. For step-by-step explanations and AWS Console instructions, refer to the infrastructure documentation.

#### Environment Variables

```bash
# Set these variables first
export YOUR_IP="YOUR_PUBLIC_IP_HERE"  # Replace with your actual IP
export KEY_NAME="your-key-pair-name"   # Replace with your key pair name
export AWS_REGION="us-east-1"
```

#### Create VPC and Networking

```bash
# Create VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=Zabbix-VPC}]' \
  --query 'Vpc.VpcId' --output text)
echo "VPC ID: $VPC_ID"

# Enable DNS
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# Create Subnet
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Zabbix-Public-Subnet}]' \
  --query 'Subnet.SubnetId' --output text)
echo "Subnet ID: $SUBNET_ID"

aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch

# Create and attach Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=Zabbix-IGW}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)
echo "IGW ID: $IGW_ID"

aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

# Configure Route Table
RTB_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" \
  --query 'RouteTables[0].RouteTableId' --output text)

aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
```

#### Create Security Groups

```bash
# Zabbix Server Security Group
SG_ZABBIX=$(aws ec2 create-security-group \
  --group-name zabbix-server-sg \
  --description "Security group for Zabbix monitoring server" \
  --vpc-id $VPC_ID --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_ZABBIX --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ZABBIX --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ZABBIX --protocol tcp --port 22 --cidr $YOUR_IP/32
aws ec2 authorize-security-group-ingress --group-id $SG_ZABBIX --protocol tcp --port 10051 --cidr 10.0.0.0/16
aws ec2 authorize-security-group-ingress --group-id $SG_ZABBIX --protocol icmp --port -1 --cidr 10.0.0.0/16

# Linux Client Security Group
SG_LINUX=$(aws ec2 create-security-group \
  --group-name linux-client-sg \
  --description "Security group for Linux monitored client" \
  --vpc-id $VPC_ID --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_LINUX --protocol tcp --port 22 --cidr $YOUR_IP/32
aws ec2 authorize-security-group-ingress --group-id $SG_LINUX --protocol tcp --port 10050 --source-group $SG_ZABBIX
aws ec2 authorize-security-group-ingress --group-id $SG_LINUX --protocol icmp --port -1 --cidr 10.0.0.0/16

# Windows Client Security Group
SG_WINDOWS=$(aws ec2 create-security-group \
  --group-name windows-client-sg \
  --description "Security group for Windows monitored client" \
  --vpc-id $VPC_ID --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_WINDOWS --protocol tcp --port 3389 --cidr $YOUR_IP/32
aws ec2 authorize-security-group-ingress --group-id $SG_WINDOWS --protocol tcp --port 10050 --source-group $SG_ZABBIX
aws ec2 authorize-security-group-ingress --group-id $SG_WINDOWS --protocol icmp --port -1 --cidr 10.0.0.0/16

echo "Security Groups created:"
echo "Zabbix Server: $SG_ZABBIX"
echo "Linux Client: $SG_LINUX"
echo "Windows Client: $SG_WINDOWS"
```

> **📖 For detailed security group rules and traffic flow diagrams**, see [Infrastructure Documentation - Security Groups](../aws-infrastructure/infra.md#security-groups)

#### Launch EC2 Instances

#### Zabbix Server Instance

**AWS Console:**

1. Go to **EC2** → **Launch Instance**
2. Configure:
   - **Name**: `Zabbix-Server`
   - **AMI**: Ubuntu Server 22.04 LTS (HVM)
   - **Instance type**: `t3.large` (or larger for production)
   - **Key pair**: Select your key pair
   - **Network settings**:
     - VPC: `Zabbix-VPC`
     - Subnet: `Zabbix-Public-Subnet`
     - Auto-assign public IP: Enable
     - Security group: `zabbix-server-sg`
   - **Storage**: 30 GB gp3
3. Click **Launch instance**

**AWS CLI:**

```bash
# Find Ubuntu 22.04 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

# Launch Zabbix Server
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.large \
  --key-name YOUR_KEY_PAIR_NAME \
  --security-group-ids $SG_ZABBIX \
  --subnet-id $SUBNET_ID \
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=30,VolumeType=gp3}' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Zabbix-Server}]'
```

#### Linux Client Instance

```bash
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name YOUR_KEY_PAIR_NAME \
  --security-group-ids $SG_LINUX \
  --subnet-id $SUBNET_ID \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Linux-Client}]'
```

#### Windows Server Instance

```bash
# Find Windows Server 2022 AMI
WIN_AMI=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=Windows_Server-2022-English-Full-Base-*" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

aws ec2 run-instances \
  --image-id $WIN_AMI \
  --instance-type t3.large \
  --key-name YOUR_KEY_PAIR_NAME \
  --security-group-ids $SG_WINDOWS \
  --subnet-id $SUBNET_ID \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Windows-Client}]'
```

### Step 7: Get Instance IPs

```bash
# Get Zabbix Server IPs
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=Zabbix-Server" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress]' \
  --output text

# Get Linux Client IPs
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=Linux-Client" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress]' \
  --output text

# Get Windows Client IPs
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=Windows-Client" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress]' \
  --output text
```

---

## Zabbix Server Installation

### Step 1: Connect to Zabbix Server

```bash
ssh -i your-key.pem ubuntu@ZABBIX_SERVER_PUBLIC_IP
```

### Step 2: Install Docker and Docker Compose

```bash
# Download and run installation script
wget https://raw.githubusercontent.com/yourusername/aws-zabbix-monitoring-infrastructure/main/zabbix-server/installation-script.sh
chmod +x installation-script.sh
sudo ./installation-script.sh

# Logout and login again (or run: newgrp docker)
exit
ssh -i your-key.pem ubuntu@ZABBIX_SERVER_PUBLIC_IP
```

### Step 3: Deploy Zabbix with Docker Compose

```bash
# Create directory
mkdir ~/zabbix-docker && cd ~/zabbix-docker

# Download docker-compose.yml
wget https://raw.githubusercontent.com/yourusername/aws-zabbix-monitoring-infrastructure/main/zabbix-server/docker-compose.yml

# Review and optionally edit the file
nano docker-compose.yml
# Change PostgreSQL password if needed

# Start containers
docker compose up -d

# Wait 2-3 minutes for initialization
sleep 180

# Check container status
docker compose ps

# View logs
docker compose logs -f
```

### Step 4: Access Zabbix Web Interface

1. Open browser: `http://ZABBIX_SERVER_PUBLIC_IP`
2. Login with default credentials:
   - **Username**: `Admin`
   - **Password**: `zabbix`
3. **Important**: Change the default password!
   - Go to **User settings** → **Change password**

---

## Linux Agent Installation

### Step 1: Connect to Linux Client

```bash
ssh -i your-key.pem ubuntu@LINUX_CLIENT_PUBLIC_IP
```

### Step 2: Install Zabbix Agent

```bash
# Download installation script
wget https://raw.githubusercontent.com/yourusername/aws-zabbix-monitoring-infrastructure/main/agents/linux/install-agent.sh
chmod +x install-agent.sh

# Run installation
# Replace ZABBIX_SERVER_PRIVATE_IP with actual private IP (e.g., 10.0.1.151)
sudo ./install-agent.sh ZABBIX_SERVER_PRIVATE_IP Linux-Client-machine
```

### Step 3: Verify Agent Status

```bash
# Check service status
sudo systemctl status zabbix-agent2

# View logs
sudo tail -f /var/log/zabbix/zabbix_agent2.log

# Test agent
sudo zabbix_agent2 -t agent.ping
# Expected output: agent.ping [t|1]
```

---

## Windows Agent Installation

### Step 1: Connect via RDP

1. Get Windows password:
   ```bash
   aws ec2 get-password-data \
     --instance-id WINDOWS_INSTANCE_ID \
     --priv-launch-key /path/to/your-key.pem
   ```

2. Connect using RDP:
   - **Computer**: `WINDOWS_PUBLIC_IP`
   - **Username**: `Administrator`
   - **Password**: (from step 1)

### Step 2: Download Zabbix Agent

1. Open Internet Explorer on Windows Server
2. Go to: https://www.zabbix.com/download_agents
3. Select **Windows** / **amd64** / **Download MSI**

Or use direct link:
```
https://cdn.zabbix.com/zabbix/binaries/stable/6.4/6.4.21/zabbix_agent-6.4.21-windows-amd64-openssl.msi
```

### Step 3: Install Agent

1. Run the downloaded `.msi` file
2. Accept license agreement
3. Configure during installation:
   - **Zabbix server IP/DNS**: `ZABBIX_SERVER_PRIVATE_IP` (e.g., 10.0.1.151)
   - **Agent listen port**: `10050`
   - **Server or Proxy for active checks**: `ZABBIX_SERVER_PRIVATE_IP`
   - **Hostname**: `Windows-Client-machine`
4. Complete installation

### Step 4: Configure Windows Firewall

```powershell
# Open PowerShell as Administrator
New-NetFirewallRule -DisplayName "Zabbix Agent" -Direction Inbound -Protocol TCP -LocalPort 10050 -Action Allow
```

### Step 5: Verify Installation

1. Press `Win + R` → type `services.msc`
2. Find "Zabbix Agent" → Verify status is "Running"
3. Check logs: `C:\Program Files\Zabbix Agent\zabbix_agentd.log`

---

## Adding Hosts to Zabbix

### Add Linux Client

1. Login to Zabbix web interface
2. Go to **Configuration** → **Hosts** → **Create host**
3. **Host** tab:
   - **Host name**: `Linux-Client-machine` (must match agent config!)
   - **Groups**: Select "Linux servers" (or create new)
   - **Interfaces**: Click **Add** → **Agent**
     - **IP address**: `LINUX_PRIVATE_IP` (e.g., 10.0.1.123)
     - **Port**: `10050`
4. **Templates** tab:
   - Click **Select** → Choose "Linux by Zabbix agent"
   - Click **Add**
5. Click **Add** (bottom of page)

### Add Windows Client

1. Go to **Configuration** → **Hosts** → **Create host**
2. **Host** tab:
   - **Host name**: `Windows-Client-machine`
   - **Groups**: Select "Windows servers"
   - **Interfaces**: Click **Add** → **Agent**
     - **IP address**: `WINDOWS_PRIVATE_IP` (e.g., 10.0.1.192)
     - **Port**: `10050`
3. **Templates** tab:
   - Click **Select** → Choose "Windows by Zabbix agent"
   - Click **Add**
4. Click **Add** (bottom of page)

---

## Verification

### Check Host Status

1. Go to **Monitoring** → **Hosts**
2. Wait 1-2 minutes for initial connection
3. Verify **ZBX** column shows **green** for both hosts ✅

### View Collected Data

1. Click on host name
2. Go to **Latest data**
3. You should see metrics like:
   - CPU usage
   - Memory usage
   - Disk space
   - Network traffic

### Test Connectivity

```bash
# From Zabbix Server, test agent connectivity
docker exec -it zabbix-server bash
zabbix_get -s LINUX_PRIVATE_IP -k agent.ping
# Expected: 1

zabbix_get -s WINDOWS_PRIVATE_IP -k agent.ping
# Expected: 1
```

---

## Post-Installation

### Security Hardening

1. **Change Default Passwords**:
   ```bash
   # Zabbix web interface: User settings → Change password
   
   # PostgreSQL (in docker-compose.yml before first run)
   # Change POSTGRES_PASSWORD to a strong password
   ```

2. **Enable HTTPS**:
   - Configure SSL certificate for Zabbix web interface
   - Update security group to only allow HTTPS (443)

3. **Restrict SSH/RDP Access**:
   - Update security groups to allow only your specific IP

4. **Regular Updates**:
   ```bash
   # Update Zabbix containers
   cd ~/zabbix-docker
   docker compose pull
   docker compose up -d
   
   # Update Ubuntu packages
   sudo apt update && sudo apt upgrade -y
   ```

### Backup Configuration

```bash
# Export AWS configurations
aws ec2 describe-vpcs --vpc-ids $VPC_ID > vpc-backup.json
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" > sg-backup.json

# Backup Zabbix database
docker exec zabbix-postgres pg_dump -U zabbix zabbix > zabbix-backup-$(date +%Y%m%d).sql
```

### Monitoring Best Practices

1. **Set up Email Notifications**:
   - Configuration → Media types → Email
   - Configure SMTP settings
   - Create actions for alerts

2. **Create Custom Dashboards**:
   - Monitoring → Dashboard → Create dashboard
   - Add widgets for key metrics

3. **Configure Triggers**:
   - Set appropriate thresholds for alerts
   - Avoid alert fatigue with proper severity levels

---

## Troubleshooting

### Common Issues

**Problem**: Can't SSH to instances
```bash
# Solution: Check security group allows SSH from your IP
aws ec2 describe-security-groups --group-ids $SG_ID

# Update security group if needed
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32
```

**Problem**: Zabbix containers won't start
```bash
# Check logs
docker compose logs

# Common issue: Port already in use
sudo netstat -tlnp | grep 80

# Restart Docker
sudo systemctl restart docker
docker compose up -d
```

**Problem**: Agent shows "Not available" (ZBX red)
```bash
# Check agent is running
systemctl status zabbix-agent2  # Linux
services.msc  # Windows

# Test connectivity from Zabbix server
docker exec -it zabbix-server bash
zabbix_get -s AGENT_IP -k agent.ping

# Check firewall/security groups
```

For more troubleshooting, see the main README.md

---

## Next Steps

- Configure email notifications
- Set up custom monitoring templates
- Create dashboards for visualization
- Implement backup strategy
- Plan for high availability (multi-AZ deployment)
- Integrate with other monitoring tools

---

**Congratulations!** 🎉 Your Zabbix monitoring infrastructure is now fully operational!