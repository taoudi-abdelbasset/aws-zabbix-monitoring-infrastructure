# Zabbix Agent Installation Guide for Windows Server

## Prerequisites

- Windows Server 2022 (or Windows Server 2019/2016)
- Administrator access
- RDP connection to the server
- Zabbix Server IP address (Private IP)

---

## Installation Steps

### Step 1: Download Zabbix Agent

1. Open a web browser on the Windows Server
2. Navigate to: https://www.zabbix.com/download_agents
3. Select the following options:
   - **Operating System:** Windows
   - **Architecture:** amd64 (64-bit)
4. Click **Download** for the MSI package
5. Save the file to your Downloads folder

**Direct Download Link :**
```
https://cdn.zabbix.com/zabbix/binaries/stable/6.4/6.4.21/zabbix_agent-6.4.21-windows-amd64-openssl.msi
```

---

### Step 2: Run the Installer

1. Navigate to your Downloads folder
2. Double-click the `.msi` file
3. Click **Next** on the welcome screen
4. Accept the license agreement → Click **Next**

---

### Step 3: Configure Agent During Installation

On the configuration screen, fill in the following:

| Field | Value | Example |
|-------|-------|---------|
| **Zabbix server IP/DNS** | Your Zabbix Server's **Private IP** | `ZABBIX_SERVER_PRIVATE_IP` |
| **Agent listen port** | `10050` (default) | `10050` |
| **Server or Proxy for active checks** | Same as Zabbix server IP | `ZABBIX_SERVER_PRIVATE_IP` |
| **Hostname** | Unique name for this Windows machine | `Windows-Client-machine` |

**Important Notes:**
- ⚠️ Use the **Private IP** of your Zabbix Server (e.g., ZABBIX_SERVER_PRIVATE_IP), NOT the public IP
- ⚠️ The **Hostname** must be unique and you'll use this exact name when adding the host in Zabbix web interface
- ⚠️ Remember this hostname - case sensitive!

---

### Step 4: Complete Installation

1. Click **Next** to continue
2. Click **Install** (may require administrator confirmation)
3. Wait for installation to complete
4. Click **Finish**

---

### Step 5: Verify Agent is Running

1. Press `Windows Key + R`
2. Type: `services.msc` and press Enter
3. Scroll down to find **"Zabbix Agent"** or **"Zabbix Agent 2"**
4. Verify the **Status** column shows **"Running"** ✅
5. If not running:
   - Right-click on "Zabbix Agent"
   - Select **Start**

---

### Step 6: Configure Windows Firewall

The Zabbix agent needs inbound access on port 10050:

#### Option A: Using GUI

1. Press `Windows Key` and type: `firewall`
2. Open **"Windows Defender Firewall with Advanced Security"**
3. Click **"Inbound Rules"** on the left panel
4. Click **"New Rule..."** on the right panel
5. Select **"Port"** → Click **Next**
6. Select **"TCP"** → Specific local ports: `10050` → Click **Next**
7. Select **"Allow the connection"** → Click **Next**
8. Check all three boxes:
   - [x] Domain
   - [x] Private
   - [x] Public
9. Click **Next**
10. Name: `Zabbix Agent` → Click **Finish**

---

### Step 7: Test Agent Configuration

1. Press `Windows Key + R`
2. Type: `cmd` and press Enter
3. Navigate to Zabbix Agent directory:
   ```cmd
   cd "C:\Program Files\Zabbix Agent"
   ```
4. Test the agent:
   ```cmd
   zabbix_agentd.exe -t agent.ping
   ```
5. Expected output:
   ```
   agent.ping                                    [t|1]
   ```

If you see `[t|1]`, the agent is working correctly!

---

## Troubleshooting

### Agent Not Starting

**Check the configuration file:**
1. Navigate to: `C:\Program Files\Zabbix Agent\`
2. Open `zabbix_agentd.conf` with Notepad (as Administrator)
3. Verify these lines:
   ```
   Server = ZABBIX_SERVER_PRIVATE_IP # Private IP of Zabbix inst
   ServerActive = ZABBIX_SERVER_PRIVATE_IP # Private IP of Zabbix inst
   Hostname = Windows-Client-machine
   ```
4. Save and restart the service

**Restart the service:**
1. Open `services.msc`
2. Find "Zabbix Agent"
3. Right-click → **Restart**

### Check Logs

View agent logs at:
```
C:\Program Files\Zabbix Agent\zabbix_agentd.log
```

Look for error messages related to:
- Connection to Zabbix Server
- Configuration errors
- Firewall issues

---

## Add Host to Zabbix Web Interface

After successful agent installation:

1. Login to Zabbix web interface: `http://YOUR_ZABBIX_SERVER_PUBLIC_IP`
2. Go to: **Configuration → Hosts**
3. Click **"Create host"**
4. Fill in details:
   - **Host name:** `Windows-Client-machine` (must match the hostname in agent config!)
   - **Groups:** Select "Windows servers"
   - **Interfaces:** 
     - Click "Add" → Select "Agent"
     - IP address: `WINDOWS_CLIENT_PRIVATE_IP` (Windows instance private IP)
     - Port: `10050`
   - **Templates:** Select "Windows by Zabbix agent"
5. Click **"Add"**
6. Wait 1-2 minutes
7. Go to **Monitoring → Hosts**
8. Verify **ZBX** status is **GREEN** ✅

---

## Configuration File Location

If you need to manually edit the configuration:

**File Path:**
```
C:\Program Files\Zabbix Agent\zabbix_agentd.conf
```

**Important:** Always restart the service after configuration changes!

---

## Uninstallation

To remove Zabbix Agent:

1. Press `Windows Key + R`
2. Type: `appwiz.cpl` and press Enter
3. Find "Zabbix Agent" in the list
4. Right-click → **Uninstall**

---

## Additional Resources

- [Official Zabbix Documentation](https://www.zabbix.com/documentation/current/manual/installation/install_from_packages/win_msi)
- [Zabbix Windows Agent Download](https://www.zabbix.com/download_agents)
- [Zabbix Forum](https://www.zabbix.com/forum/)

---

## Notes

- **Default Installation Path:** `C:\Program Files\Zabbix Agent\`
- **Service Name:** Zabbix Agent
- **Default Port:** 10050 (TCP)
- **Log File:** `C:\Program Files\Zabbix Agent\zabbix_agentd.log`
- **Config File:** `C:\Program Files\Zabbix Agent\zabbix_agentd.conf`