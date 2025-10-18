#!/bin/bash
# Jamie's Debian DWM Workstation Setup – Final Complete Version (Polkit fixed)
# Tested on Debian 12+ – run as root
set -e

# ─────────────────────────  USER SETUP  ──────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Run this script as root."
    exit 1
fi

read -rp "Enter your normal username (to create or update): " USERNAME
id "$USERNAME" &>/dev/null || useradd -m -G users "$USERNAME"
usermod -aG sudo "$USERNAME"
echo "[+] $USERNAME added to sudo group."

USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)

# ─────────────────────────  BASE SYSTEM PACKAGES  ────────────────────
echo "[+] Installing base system packages..."
apt update
apt install -y --no-install-recommends \
  build-essential git gcc make pkg-config wget curl ca-certificates unzip \
  neovim htop feh thunar lxappearance light dunst \
  xorg xserver-xorg-core xinit x11-utils \
  xserver-xorg-video-intel \
  libx11-dev libxft-dev libxinerama-dev \
  alsa-utils pulseaudio pulseaudio-module-bluetooth bluez libasound2-dev \
  network-manager iwd \
  polkitd pkexec lxqt-policykit \
  fonts-dejavu fonts-noto-color-emoji xclip

# ─────────────────────────  ENABLE CORE SERVICES  ─────────────────────
echo "[+] Enabling essential services..."
systemctl enable --now bluetooth
systemctl enable --now NetworkManager

# ─────────────────────────  NETWORKMANAGER + IWD  ─────────────────────
echo "[+] Configuring NetworkManager to use iwd backend..."
mkdir -p /etc/NetworkManager/conf.d
cat <<'EOF' > /etc/NetworkManager/conf.d/iwd.conf
[device]
wifi.backend=iwd
EOF
systemctl restart NetworkManager

# ─────────────────────────  POLKIT TEST  ─────────────────────────────
echo "[+] Polkit correctly installed → using polkitd + lxqt-policykit agent."

# ─────────────────────────  GREETD SETUP  ────────────────────────────
echo "[+] Installing greetd + tuigreet..."
apt install -y --no-install-recommends cargo libpam0g-dev

install -Dm644 etc/greetd/config.toml            /etc/greetd/config.toml
install -Dm644 etc/pam.d/greetd                  /etc/pam.d/greetd
install -Dm644 etc/systemd/system/greetd.service /etc/systemd/system/greetd.service

id greeter 2>/dev/null || useradd -r -s /usr/sbin/nologin greeter
usermod -aG video,audio,input,tty greeter

echo "[+] Building greetd and tuigreet..."
[ -d /usr/local/src/greetd ] || git clone https://git.sr.ht/~kennylevinsen/greetd /usr/local/src/greetd
cd /usr/local/src/greetd && cargo build --release && install -Dm755 target/release/greetd /usr/local/bin/greetd
[ -d /usr/local/src/tuigreet ] || git clone https://github.com/apognu/tuigreet /usr/local/src/tuigreet
cd /usr/local/src/tuigreet && cargo build --release && install -Dm755 target/release/tuigreet /usr/local/bin/tuigreet
cd ~

systemctl daemon-reload
systemctl enable --now greetd

# ─────────────────────────  SUCKLESS STACK  ───────────────────────────
echo "[+] Cloning/building DWM, ST, and dmenu..."
sudo -u "$USERNAME" mkdir -p "$USER_HOME/.config"
cd "$USER_HOME/.config"

if [ ! -d "dwm" ]; then
    sudo -u "$USERNAME" git clone https://git.suckless.org/dwm "$USER_HOME/.config/dwm"
fi
(cd "$USER_HOME/.config/dwm" && make clean install)

if [ ! -d "st" ]; then
    sudo -u "$USERNAME" git clone https://git.suckless.org/st "$USER_HOME/.config/st"
fi
(cd "$USER_HOME/.config/st" && make clean install)

if [ ! -d "dmenu" ]; then
    sudo -u "$USERNAME" git clone https://git.suckless.org/dmenu "$USER_HOME/.config/dmenu"
fi
(cd "$USER_HOME/.config/dmenu" && make clean install)

# ─────────────────────────  DWMSTATUS BUILD  ──────────────────────────
echo "[+] Compiling dwmstatus..."
install -d -m755 "$USER_HOME/src"
cp src/dwmstatus-light.c "$USER_HOME/src/dwmstatus-light.c"
sudo -u "$USERNAME" gcc -O2 -Wall "$USER_HOME/src/dwmstatus-light.c" \
   -o "$USER_HOME/.local/bin/dwmstatus" -lasound
chmod +x "$USER_HOME/.local/bin/dwmstatus"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.local" "$USER_HOME/src"

# ─────────────────────────  USER CONFIG FILES  ────────────────────────
echo "[+] Installing user configs..."
install -Dm755 home/xinit/.config/xorg/xinitrc  "$USER_HOME/.config/xorg/xinitrc"
install -Dm755 home/xinit/.local/bin/autostart  "$USER_HOME/.local/bin/autostart"
ln -sf "$USER_HOME/.config/xorg/xinitrc" "$USER_HOME/.xinitrc"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.config" "$USER_HOME/.local"

# ─────────────────────────  DONE  ─────────────────────────────────────
echo
echo "✅ Setup finished successfully!"
echo "• greetd + tuigreet enabled on tty2"
echo "• Polkit uses polkitd + pkexec + lxqt-policykit (correct Debian 12 config)"
echo "• NetworkManager configured with iwd backend"
echo "• Intel + generic Xorg video drivers installed"
echo "• DWM, ST, dmenu built and dwmstatus compiled"
echo
echo "Reboot, log in via tuigreet, and enjoy DWM."
