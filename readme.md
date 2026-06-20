# Raspberry Pi Passive‑Income Appliance
## Honeygain • Pawns • TraffMonetizer • Dozzle • Netdata • Dashboard • Diagnostics
## A Docker‑based passive‑income appliance for Raspberry Pi.

🤝 Support This Project (Referral Links)
In full transparency:
This project is completely free, open‑source, and the only way I earn anything from it is if people choose to use my referral links.

If this appliance saves you time, simplifies your setup, or you just want to support ongoing development, using the links below genuinely helps.

⭐ My Referral Links
Honeygain — https://join.honeygain.com/EASYE2EE

Pawns.app — https://pawns.app/?r=19391092

EarnApp — https://earnapp.com/i/pKq8kLVd

TraffMonetizer — https://traffmonetizer.com/?aff=2128486

Using them costs you nothing extra, but it directly supports the project and helps me keep improving everything.

❓ Why Use These Services?
These platforms are the core earning components of this appliance. Each one provides a small, steady passive‑income stream by sharing unused network bandwidth. When combined, they turn a Raspberry Pi into a low‑maintenance earning device that runs quietly in the background.

Honeygain — The most established bandwidth‑sharing platform with consistent payouts.

Pawns.app — Simple, reliable, and works perfectly alongside Honeygain.

TraffMonetizer — Lightweight and adds a bit of extra income with almost zero overhead.

EarnApp — Higher earning potential and native ARM support, making it ideal for Raspberry Pi.

Running all of them together maximizes your Pi’s earning potential while keeping resource usage low and stability high.

❤️ How Referrals Help the Project
This project takes a lot of time to build, test, maintain, and support — especially with Raspberry Pi quirks, Docker updates, and service changes.

I don’t run ads.
I don’t sell anything.
I don’t lock features behind paywalls.

Referral bonuses are the only way I earn anything from this project.

When you sign up using my links:

You pay nothing extra

You get the same service and payouts

I receive a small bonus that helps me:

Keep the installer updated

Add new services

Improve the dashboard UI

Maintain compatibility with new Raspberry Pi OS releases

Build more tools like the diagnostics API and watchdog system

## 🚀 What This Appliance Does  
This project turns any Raspberry Pi (ARM64 recommended) into a zero‑touch passive‑income appliance running:  
• 	Honeygain — passive bandwidth sharing  
• 	Pawns.app — passive bandwidth sharing  
• 	TraffMonetizer — optional traffic monetization with dashboard reporting  
• 	Dozzle — real‑time logs  
• 	Netdata — system performance dashboard  
• 	Dashboard UI — clean landing page  
• 	Diagnostics API — one‑click system health report  
• 	EarnApp — optional native host service (not containerized)  
Everything runs in Docker except optional native EarnApp support.  
Everything is monitored.  
Everything is self‑healing.  
Everything is remote‑friendly.  

## ⚠️ Before You Install  
**Only works with OS Bookworm**
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
git clone https://github.com/easye35/Raspberry-PI-Earning.git
cd Raspberry-PI-Earning
chmod +x install.sh
sudo ./install.sh
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
## 🐳 Docker
The installer automatically:  
• 	Installs Docker  
• 	Generates **`.env`**      
• 	Deploys the full stack via Docker Compose
No Portainer.
No manual host configuration.

> EarnApp is not deployed as a Docker service. If you want EarnApp, install it natively on the Raspberry Pi and the repo can optionally detect it after install.

### 📊 Your Dashboard
After installation, you get a clean, modern dashboard:

Dashboard UI
Your main landing page:
```bash
http://<PI-IP>
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
• 	Dozzle  
• 	Diagnostics API  

Netdata (System Metrics)
```bash
http://<PI-IP>:19999
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

### 🌐 Remote Access (Optional)
## ⭐ Tailscale (Best Option)
Install on the Pi:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```
Then access your appliance from anywhere:
```bash
http://100.x.x.x   # Dashboard
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
    <tr><td><strong>Dozzle</strong></td><td>Real‑time logs</td></tr>
    <tr><td><strong>Glances</strong></td><td>System metrics</td></tr>
    <tr><td><strong>Dashboard</strong></td><td>Clean landing page</td></tr>
    <tr><td><strong>Diagnostics</strong></td><td>Live system health API</td></tr>
  </tbody>
</table>

## 🧰 Files Included
The repo now includes:
- **`install.sh`** — interactive installer
- **`docker-compose.yml`** — full Docker Compose stack
- **`scripts/watchdog.sh`** — self‑healing logic
- **`dashboard/index.html`** — dashboard UI
- **`README.md`** — this file
Everything is generated automatically on install.