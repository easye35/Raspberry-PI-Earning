# Raspberry Pi Passive‑Income Appliance  
### EarnApp • Honeygain • Pawns • Watchtower • Portainer  
Fully automated, self‑healing, Docker‑based earning stack for Raspberry Pi.

---

## 🚀 What This Appliance Does
This project turns any Raspberry Pi (ARM64 recommended) into a **fully automated passive‑income appliance** running:

- **EarnApp** (token auto‑extracted from your registration link)
- **Honeygain** (email + password)
- **Pawns.app** (email + password)
- **Watchtower** (auto‑updates all containers)
- **Portainer** (web UI for managing everything)

All containers run under Docker.  
EarnApp runs via x86 emulation (handled automatically).

---

## ⚠️ Before You Install  
If you previously attempted an install or something failed halfway, **you MUST clean the system first**.

Run:

```bash
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo apt remove -y docker docker.io docker-ce docker-ce-cli containerd.io
sudo apt autoremove -y
sudo reboot
```
# 📦 Installation (New Interactive Installer)
Clone the repo:
```bash
git clone https://github.com/easye35/Raspberry-PI-docker-Earning
cd Raspberry-PI-docker-Earning
chmod +x install.sh
./install.sh
```
# The installer will now prompt you interactively for everything:
### 🔐 Portainer
- Admin password (no more .env entry)

### 🐝 Honeygain
- Email  
- Password  

### 🐾 Pawns.app
- Email  
- Password  

### 💰 EarnApp
- Paste your EarnApp registration link  
- Installer auto‑extracts the token  
- Only the token is stored in `.env`

### 🐳 Docker + Emulation
The installer automatically:
- Installs Docker  
- Enables x86 emulation for EarnApp  
- Installs Portainer  
- Deploys the full stack via Portainer API
