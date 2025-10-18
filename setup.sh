#!/bin/bash
# Jamie's Debian DWM Workstation setup installer
# Works on minimal Debian 12+; run as root
set -e

# ─────────────────────────── USER SETUP ─────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Please run this script as root."
    exit 1
fi

read -rp "Enter your normal username: " USERNAME
id "$USERNAME" &>/dev/null || useradd -m -G users "$USERNAME"
usermod -aG sudo "$USERNAME"
echo "[+] $USERNAME added to sudo group."

USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)

# ─────────────────────────── DEPENDENCIES ───────────────────────────
echo "[+] Installing minimal dependencies..."
apt update
apt install -y --no-install-recommends \
  build-essential git gcc make pkg-config \
  xorg xserver-xorg-core xinit x11-utils \
  libx11-dev libxft-dev libxinerama-dev \
  libasound2-dev alsa-utils pulseaudio bluez \
  policykit-1 lxqt-policykit feh thunar \
  network-manager iwd fonts-dejavu fonts-noto-color-emoji

systemctl enable NetworkManager
systemctl start NetworkManager

# ─────────────────────────── SYSTEM CONFIGS ─────────────────────────
echo "[+] Copying system configuration files..."

install -Dm644 etc/greetd/config.toml      /etc/greetd/config.toml
install -Dm644 etc/pam.d/greetd            /etc/pam.d/greetd
install -Dm644 etc/systemd/system/greetd.service \
                                           /etc/systemd/system/greetd.service

id greeter 2>/dev/null || useradd -r -s /usr/sbin/nologin greeter
usermod -aG video,audio,input,tty greeter

systemctl daemon-reload
systemctl enable --now greetd

# ─────────────────────────── USER CONFIGS ───────────────────────────
echo "[+] Installing user configuration files..."

install -Dm755 home/xinit/.config/xorg/xinitrc     "$USER_HOME/.config/xorg/xinitrc"
install -Dm755 home/xinit/.local/bin/autostart     "$USER_HOME/.local/bin/autostart"

# Create xinitrc symlink
ln -sf "$USER_HOME/.config/xorg/xinitrc" "$USER_HOME/.xinitrc"

chown -R "$USERNAME:$USERNAME" "$USER_HOME/.config" "$USER_HOME/.local"

# ─────────────────────────── BUILD DWMSTATUS ─────────────────────────
echo "[+] Building dwmstatus from source..."

install -d -m755 "$USER_HOME/src"
cp src/dwmstatus-light.c "$USER_HOME/src/dwmstatus-light.c"

sudo -u "$USERNAME" gcc -O2 -Wall "$USER_HOME/src/dwmstatus-light.c" \
    -o "$USER_HOME/.local/bin/dwmstatus" -lasound

chmod +x "$USER_HOME/.local/bin/dwmstatus"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.local" "$USER_HOME/src"

# ─────────────────────────── DONE ───────────────────────────────────
echo
echo "✅ Installation complete."
echo "Reboot and log in via tuigreet; DWM will start automatically."
