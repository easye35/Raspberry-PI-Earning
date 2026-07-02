📘 Raspberry Pi Passive‑Income Appliance — Setup Guide
Honeygain • Pawns • TraffMonetizer • Repocket • Dozzle • Netdata • Dashboard • Diagnostics
A Docker‑based passive‑income appliance for Raspberry Pi
🤝 Support This Project (Referral Links)
This project is completely free and open‑source.
The only way I earn anything from it is if people choose to use my referral links.

If this appliance saves you time, simplifies your setup, or you just want to support ongoing development, using the links below genuinely helps — and costs you nothing.

⭐ Referral Links
Pawns.app — https://pawns.app/?r=19391092

EarnApp — https://earnapp.com/i/pKq8kLVd

TraffMonetizer — https://traffmonetizer.com/?aff=2128486

❤️ Why Use Them?
These services are the core earning components of this appliance.
Using the referral links:

Gives you the same payouts

Costs nothing extra

Helps me maintain and improve the project

Supports updates, new features, and compatibility fixes

🚀 What This Appliance Does
This project turns any Raspberry Pi (ARM64 recommended) into a zero‑touch passive‑income appliance running:

Honeygain — passive bandwidth sharing

Pawns.app — passive bandwidth sharing

TraffMonetizer — optional traffic monetization with dashboard reporting

Dozzle — real‑time logs

Netdata — system performance dashboard

Dashboard UI — clean landing page

Diagnostics API — one‑click system health report

EarnApp — optional native host service (not containerized)

Repocket — optional native host service (not containerized)

Everything runs in Docker except optional native EarnApp support.
Everything is monitored.
Everything is self‑healing.
Everything is remote‑friendly.

⚠️ Before You Install
Requires Raspberry Pi OS Bookworm.

If you previously attempted an install or something failed halfway, clean the system first:

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
📦 Installation (Interactive Installer)
Clone the repo:

```bash
git clone https://github.com/easye35/Raspberry-PI-Earning.git
cd Raspberry-PI-Earning
chmod +x install.sh
sudo ./install.sh
```
🧩 Installer Prompts
🐝 Honeygain
Email

Password

🐾 Pawns.app
Email

Password

💰 TraffMonetizer
Token

 Remote Access (Optional)
Install Tailscale? (y/N)

If yes, authenticate later with:

```bash
sudo tailscale up
```
🐳 Docker
The installer automatically:

Installs Docker

Generates .env

Deploys the full stack via Docker Compose

No Portainer.
No manual host configuration.

EarnApp is not deployed as a Docker service.
If you want EarnApp, install it natively on the Raspberry Pi.
The repo can detect it after install.

🖥️ Your Dashboard
After installation, open:

```Code
http://<PI-IP>
```
You’ll see:

Service overview

Quick links

First‑run checklist

Diagnostics button

Appliance summary

Dozzle (Real‑Time Logs)
```Code
http://<PI-IP>:9999
Netdata (System Metrics)
```
```Code
http://<PI-IP>:19999
Diagnostics API
```
```Code
http://<PI-IP>:7000
🌐 Remote Access (Optional)
⭐ Tailscale (Recommended)
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```
Then access your appliance from anywhere:

```Code
http://100.x.x.x        # Dashboard
http://100.x.x.x:9999   # Logs
http://100.x.x.x:19999  # System metrics
http://100.x.x.x:7000   # Diagnostics API
```
No port forwarding.
No firewall headaches.
Fully encrypted.

🧱 Stack Overview
Component	Purpose
Honeygain	Passive income stream
Pawns	Passive income stream
TraffMonetizer	Extra passive income
Dozzle	Real‑time logs
Netdata	System metrics
Dashboard	Clean landing page
Diagnostics	Live system health API


🧰 Files Included
install.sh — interactive installer

docker-compose.yml — full Docker Compose stack

scripts/watchdog.sh — self‑healing logic

dashboard/index.html — dashboard UI

README.md — this file

Everything is generated automatically on install.
