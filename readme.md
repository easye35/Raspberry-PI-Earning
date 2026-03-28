<div align="center">
---

# 💰 Referral Links

If you want to support this project (and get bonuses on signup), feel free to use my referral links below:

### 🟦 EarnApp  
👉 **Sign up with my referral link:**  
(https://earnapp.com/i/pKq8kLVd)

### 🟨 Honeygain  
👉 **Get a $5 bonus using my link:**  
(https://join.honeygain.com/EASYE2EE)

### 🟧 Pawns.app  
👉 **Earn more with my referral:**  
(https://pawns.app/?r=19391092)
---

# ⚡ Raspberry‑PI‑docker‑Earning ⚡  
### Turn your Raspberry Pi into a fully automated, self‑healing passive‑income appliance.

---

### 🐳 Docker • 📦 Portainer • 💸 EarnApp • 🐝 Honeygain • 🐾 Pawns • 🔄 Auto‑Updating Watchtower

---

<img src="https://img.shields.io/badge/Raspberry%20Pi-Automation-red?style=for-the-badge">
<img src="https://img.shields.io/badge/Docker-Enabled-blue?style=for-the-badge">
<img src="https://img.shields.io/badge/Portainer-Managed-0db7ed?style=for-the-badge">
<img src="https://img.shields.io/badge/Passive%20Income-Online-success?style=for-the-badge">

</div>

---

# 🚀 One‑Line Installer

Run this on a **fresh Raspberry Pi OS (64‑bit)**:

```bash
bash <(curl -s https://raw.githubusercontent.com/easye35/Raspberry-PI-docker-Earning/main/install.sh)
```
# 🛠️ Setup Instructions
1️⃣ Clone the repository
```bash
cd ~
rm -rf Raspberry-PI-docker-Earning
git clone https://github.com/easye35/Raspberry-PI-docker-Earning.git
cd Raspberry-PI-docker-Earning
chmod +x install.sh
./install.sh
```
# 2️⃣ Edit the .env file
This file controls all configuration.
Open .env and fill in:
- Portainer admin password
- Honeygain email/password
- Pawns email/password
- Device names
- (EarnApp token will be auto-filled later)
Example:
```env
PORTAINER_PASSWORD=MyStrongPassword123

HONEYGAIN_EMAIL=me@example.com
HONEYGAIN_PASSWORD=secret
HONEYGAIN_DEVICE=PI1

PAWNS_EMAIL=me@example.com
PAWNS_PASSWORD=secret
PAWNS_DEVICE=PI1

EARNAPP_TOKEN=REPLACE_ME

WATCHTOWER_SCHEDULE="0 */6 * * *"
```
# Run the installer
```bash
chmod +x install.sh
./install.sh
```
The installer will:
- Install Docker + Portainer
- Initialize Portainer with your password
- Run EarnApp installer
- Extract your EarnApp token
- Save token into .env
- Build the final stack
- Deploy it automatically via Portainer API
When it finishes, your Pi is fully operational.

# 🖥 Accessing Portainer
After installation, open:
https://<PI-IP>:9443


Login with:
- Username: admin
- Password: (from .env)
Inside Portainer, you’ll see your stack:
Raspberry-PI-docker-Earning


Click it to view:
- EarnApp
- Honeygain
- Pawns
- Watchtower

# 🔧 Updating Credentials
If you ever need to change:
- Honeygain login
- Pawns login
- Device names
- Watchtower schedule
Just edit .env and redeploy the stack in Portainer.
EarnApp token stays unless you reinstall.

---

# 🌡️ Raspberry Pi Temperature & Health Monitoring

Your Pi now includes a **full hardware monitoring dashboard** powered by the `rpi-monitoring` container.

This gives you real‑time visibility into:

- CPU temperature  
- Voltage & throttling warnings  
- CPU load  
- Memory usage  
- Disk usage  
- Uptime  
- System health indicators  

### 🔍 Access the Monitoring Dashboard

Once your stack is running, open:
```bash
http://<PI-IP>:8888
```
# 🔄 Auto‑Healing & Auto‑Updating
The unified Watchtower container:
- Updates all containers
- Restarts crashed containers
- Revives stopped containers
- Cleans up old images
- Runs on your schedule
This keeps your Pi earning with zero maintenance.

# 🧠 Notes
- EarnApp token is auto‑extracted and saved into .env
- Everything runs in Docker for isolation and stability
- Works on any Raspberry Pi with 64‑bit OS
- Designed for long‑term unattended operation

## 🔐 How to Set a Pawns Password if You Signed Up with Google Login
Some users sign up for Pawns.app using the “Continue with Google” button.
When you do this, Pawns does NOT create a password for your account — Google handles the login for you.
But your Docker container cannot use Google login, so you need to create a password manually.
Here’s how to do it:
✅ Step‑by‑step
- Go to the Pawns login page:
<https://pawns.app/login>
- Click “Forgot password?”
- Enter the same email you used when signing in with Google.
- Pawns will send you a password reset email.
- Create a new password — this becomes your Docker login password.
- Update your .env file:
```bash
PAWNS_EMAIL=your_google_email@example.com
PAWNS_PASSWORD=the_password_you_just_created
PAWNS_DEVICE=PI1
```

- Redeploy your stack in Portainer.
🎉 Done!
You now have a real password that works with:
- Your Docker container
- API logins
- Manual logins
- Anything outside Google OAuth
This is the official and correct way to use Pawns with Docker.
