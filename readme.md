# Raspberry Pi Passive‑Income Appliance
## Honeygain • Pawns • Watchtower • Watchdog • Dashboard • Diagnostics
## A fully automated, self‑healing, Docker‑based earning appliance for Raspberry Pi.

## 🚀 What This Appliance Does  
This project turns any Raspberry Pi (ARM64 recommended) into a zero‑touch passive‑income appliance running:  
• 	Honeygain — passive bandwidth sharing  
• 	Pawns.app — passive bandwidth sharing  
• 	Watchtower — automatic container updates  
• 	Watchdog — self‑healing restarts + service recovery  
• 	Dozzle — real‑time logs  
• 	Glances — system metrics dashboard  
• 	Dashboard UI — clean landing page  
• 	Diagnostics API — one‑click system health report  
Everything runs in Docker.  
Everything is monitored.  
Everything is self‑healing.  
Everything is remote‑friendly.  

## ⚠️ Before You Install  
If you previously attempted an install or something failed halfway, you MUST clean the system first.  
Run:  
```bash
# Stop and remove all Docker containers
sudo docker stop $(sudo docker ps -aq) 2>/dev/null
sudo docker rm $(sudo docker ps -aq) 2>/dev/null

# Remove Docker data directories
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# Remove Docker packages
sudo apt remove -y docker docker.io docker-ce docker-ce-cli containerd.io
sudo apt autoremove -y

# Remove ALL repo folders anywhere in your home directory
find ~ -type d -iname "raspberry-pi-docker-earning*" -exec rm -rf {} +

# Reboot to ensure a clean environment
sudo reboot
```
## 📦 Installation (Interactive Installer)
Clone the repo:
```bsh
git clone https://github.com/easye35/Raspberry-PI-docker-Earning
cd Raspberry-PI-docker-Earning
chmod +x install.sh
./install.sh
```
## 🧩 The installer will prompt you for:
### 🐝 Honeygain  
• 	Email  
• 	Password  
### 🐾 Pawns.app
• 	Email  
• 	Password  
## 🌐 Remote Access (Optional)  
• 	Install Tailscale? (y/N)  
• 	If yes → installer installs Tailscale  
• 	You authenticate later with:  
```bash
sudo tailscale up
```
## 🐳 Docker + Emulation
The installer automatically:  
• 	Installs Docker  
• 	Enables x86 emulation (for compatibility)  
• 	Generates **`.env`**      
• 	Creates:    
• 	**`watchdog.sh`**  
• 	**`diagnostics-server.sh`**  
• 	**`dashboard/index.html`**  
• 	Deploys the full stack via Docker Compose
No Portainer.
No EarnApp.
No manual setup.

### 📊 Your Dashboard
After installation, you get a clean, modern dashboard:

Dashboard UI
Your main landing page:
```bash
http://<PI-IP>:8088
```
Shows:
- Service overview
- Quick links
- First‑run checklist
- Diagnostics button
- Appliance summary

Dozzle (Real‑Time Logs)
```bash
http://<PI-IP>:9999
```
Live logs for:  
• 	Honeygain  
• 	Pawns  
• 	Watchtower  
• 	Watchdog  
• 	Diagnostics server  

Glances (System Metrics)
```bash
http://<PI-IP>:61208
```
Shows:
- CPU load
- RAM usage
- Disk usage
- Temperature
- Network throughput

Diagnostics API (New!)
```bash
http://<PI-IP>:7000
```
Returns JSON with:  
• 	Docker status  
• 	Container status  
• 	Healthchecks  
• 	CPU / RAM / Disk  
• 	Temperature  
• 	Internet connectivity  
The dashboard UI includes a Run Diagnostics button that fetches this live.  

## 🛡 Self‑Healing Watchdog  
The watchdog container:  
• 	Monitors all services  
• 	Restarts anything that stops  
• 	Detects Docker daemon issues  
- Logs recovery events  
- Ensures the appliance stays earning 24/7  

### 🌐 Remote Access (Optional)
## ⭐ Tailscale (Best Option)
Install on the Pi:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```
Then access your appliance from anywhere:
```bash
http://100.x.x.x:8088   # Dashboard
http://100.x.x.x:9999   # Logs
http://100.x.x.x:61208  # System metrics
http://100.x.x.x:7000   # Diagnostics API
```
No port forwarding.
No firewall headaches.
Fully encrypted.

### 🧱 Stack Overview
<table width="100%">
  <thead>
    <tr>
      <th align="left">Component</th>
      <th align="left">Purpose</th>
    </tr>
  </thead>
  <tbody>
    <tr><td><strong>Honeygain</strong></td><td>Passive income stream</td></tr>
    <tr><td><strong>Pawns</strong></td><td>Passive income stream</td></tr>
    <tr><td><strong>Watchtower</strong></td><td>Auto‑updates containers</td></tr>
    <tr><td><strong>Watchdog</strong></td><td>Self‑healing + restarts</td></tr>
    <tr><td><strong>Dozzle</strong></td><td>Real‑time logs</td></tr>
    <tr><td><strong>Glances</strong></td><td>System metrics</td></tr>
    <tr><td><strong>Dashboard</strong></td><td>Clean landing page</td></tr>
    <tr><td><strong>Diagnostics</strong></td><td>Live system health API</td></tr>
  </tbody>
</table>

## 🧰 Files Included
The repo now includes:
- **`install.sh`** — interactive installer
- **`stack.yml`** — full Docker Compose stack
- **`watchdog.sh`** — self‑healing logic
- **`diagnostics-server.sh`** — diagnostics API
- **`dashboard/index.html`** — dashboard UI
- **`README.md`** — this file
Everything is generated automatically on install.


