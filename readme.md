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
