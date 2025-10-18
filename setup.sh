#!/bin/bash
#
# Debian Minimal + DWM + ST + DMENU + greetd/tuigreet setup
# For ThinkPad T480s (Intel, minimal Debian 12+)
# ----------------------------------------------------------
set -e

# ─────────────────────── USER SETUP ─────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Please run this script as root."
    exit 1
fi

read -rp "Enter your normal username (to create or update): " USERNAME
id "$USERNAME" &>/dev/null || useradd -m -G users "$USERNAME"
usermod -aG sudo "$USERNAME"
echo "[+] $USERNAME added to sudo group."

# Optional: set password
if ! passwd -S "$USERNAME" | grep -q "P"; then
    echo "[+] Please set a password for $USERNAME:"
    passwd "$USERNAME"
fi

USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)

apt update
apt install -y sudo git curl wget ca-certificates

# ─────────────────────── BASE TOOLCHAIN ─────────────────────────
echo "[+] Installing build toolchain..."
apt install -y --no-install-recommends \
  build-essential make gcc pkg-config neovim htop unzip git

# ─────────────────────── XORG + INTEL VIDEO ─────────────────────
echo "[+] Installing Xorg and Intel video..."
apt install -y --no-install-recommends \
  xserver-xorg-core xserver-xorg-video-intel xserver-xorg-input-libinput xinit \
  libx11-dev libxft-dev libxinerama-dev x11-utils

# ─────────────────────── AUDIO + BLUETOOTH ──────────────────────
echo "[+] Installing ALSA, PulseAudio, Bluetooth..."
apt install -y --no-install-recommends \
  alsa-utils pulseaudio pulseaudio-module-bluetooth bluez libbluetooth-dev
systemctl enable bluetooth
systemctl start bluetooth

# ─────────────────────── NETWORKMANAGER + IWD ───────────────────
echo "[+] Installing NetworkManager and iwd..."
apt install -y --no-install-recommends network-manager iwd
systemctl enable NetworkManager
systemctl start NetworkManager
echo -e "[device]\nwifi.backend=iwd" | tee /etc/NetworkManager/NetworkManager.conf >/dev/null
systemctl restart NetworkManager

# ─────────────────────── POLKIT ─────────────────────────────────
echo "[+] Installing Polkit and policy agent..."
apt install -y --no-install-recommends polkitd pkexec lxqt-policykit

# ─────────────────────── FONTS + UTILITIES ──────────────────────
echo "[+] Installing fonts and lightweight utilities..."
apt install -y --no-install-recommends \
  feh lxappearance thunar xclip fonts-dejavu fonts-noto-color-emoji

# ─────────────────────── SUCKLESS SOFTWARE ──────────────────────
echo "[+] Cloning & building suckless software..."
sudo -u "$USERNAME" mkdir -p "$USER_HOME/.config"
cd "$USER_HOME/.config"

# DWM
if [ ! -d "dwm" ]; then
  sudo -u "$USERNAME" git clone https://git.suckless.org/dwm "$USER_HOME/.config/dwm"
fi
(cd "$USER_HOME/.config/dwm" && make clean install)

# ST
if [ ! -d "st" ]; then
  sudo -u "$USERNAME" git clone https://git.suckless.org/st "$USER_HOME/.config/st"
fi
(cd "$USER_HOME/.config/st" && make clean install)

# DMENU
if [ ! -d "dmenu" ]; then
  sudo -u "$USERNAME" git clone https://git.suckless.org/dmenu "$USER_HOME/.config/dmenu"
fi
(cd "$USER_HOME/.config/dmenu" && make clean install)

# ─────────────────────── DWMSTATUS (C program) ──────────────────────
echo "[+] Building dwmstatus..."
apt install -y --no-install-recommends libasound2-dev
sudo -u "$USERNAME" mkdir -p "$USER_HOME/src" "$USER_HOME/.local/bin"
cat <<'EOF' > "$USER_HOME/src/dwmstatus-ultra-alsa.c"
#include <alsa/asoundlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define STR_LEN 256
void readfile(const char *path, char *buf, size_t size){FILE*f=fopen(path,"r");if(!f){buf[0]='\0';return;}if(fgets(buf,size,f)==NULL)buf[0]='\0';fclose(f);size_t l=strlen(buf);if(l>0&&buf[l-1]=='\n')buf[l-1]='\0';}
void get_time_str(char*b,size_t s){time_t n=time(NULL);struct tm *t=localtime(&n);strftime(b,s,"%a %d %b %H:%M",t);}
void get_battery(char*b,size_t s){char c[16],st[32];readfile("/sys/class/power_supply/BAT0/capacity",c,16);readfile("/sys/class/power_supply/BAT0/status",st,32);if(!strlen(c)){b[0]='\0';return;}if(!strncmp(st,"Charging",8))snprintf(b,s,"⚡%s%%",c);else snprintf(b,s,"🔋%s%%",c);}
void get_bt(char*b,size_t s){char v[8];readfile("/sys/class/bluetooth/hci0/connected",v,8);if(strlen(v)&&v[0]=='1')snprintf(b,s,"");else snprintf(b,s," ");}
void get_vol(char*b,size_t s){long mn,mx,v;snd_mixer_t*h;snd_mixer_selem_id_t*i;const char*m="Master",*c="default";snd_mixer_elem_t*e;if(snd_mixer_open(&h,0)<0||snd_mixer_attach(h,c)<0||snd_mixer_selem_register(h,NULL,NULL)<0||snd_mixer_load(h)<0){snprintf(b,s,"VOL:--");if(h)snd_mixer_close(h);return;}snd_mixer_selem_id_malloc(&i);snd_mixer_selem_id_set_index(i,0);snd_mixer_selem_id_set_name(i,m);e=snd_mixer_find_selem(h,i);if(!e){snprintf(b,s,"VOL:--");}else{snd_mixer_selem_get_playback_volume_range(e,&mn,&mx);snd_mixer_selem_get_playback_volume(e,SND_MIXER_SCHN_FRONT_LEFT,&v);double p=((double)(v-mn)/(mx-mn))*100.0;snprintf(b,s,"VOL:%ld%%",(long)p);}snd_mixer_close(h);snd_mixer_selem_id_free(i);}
int main(void){char t[64],bat[32],vol[32],bt[8],stat[STR_LEN],cmd[STR_LEN+50];for(;;){get_time_str(t,64);get_battery(bat,32);get_vol(vol,32);get_bt(bt,8);snprintf(stat,STR_LEN,"%s %s | %s | %s",bt,vol,bat,t);snprintf(cmd,sizeof(cmd),"/usr/bin/xsetroot -name \"%s\"",stat);system(cmd);sleep(10);}return 0;}
EOF
gcc -O2 -Wall "$USER_HOME/src/dwmstatus-ultra-alsa.c" -o "$USER_HOME/.local/bin/dwmstatus" -lasound
chmod +x "$USER_HOME/.local/bin/dwmstatus"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.local" "$USER_HOME/src"

# ─────────────────────── GREETD + TUIGREET ──────────────────────
echo "[+] Installing greetd + tuigreet..."
apt install -y --no-install-recommends build-essential cargo libpam0g-dev git

cd /usr/local/src
[ -d greetd ] || git clone https://git.sr.ht/~kennylevinsen/greetd
cd greetd && cargo build --release && cp target/release/greetd /usr/local/bin/
cd ..

[ -d tuigreet ] || git clone https://github.com/apognu/tuigreet.git
cd tuigreet && cargo build --release && cp target/release/tuigreet /usr/local/bin/
cd ..

mkdir -p /etc/greetd
cat <<'EOF' > /etc/greetd/config.toml
[terminal]
vt = 2

[default_session]
command = "tuigreet --cmd startx --remember --time"
user = "greeter"
EOF

# PAM config for greetd
cat <<'EOF' > /etc/pam.d/greetd
auth        include        login
account     include        login
password    include        login
session     include        login
EOF

chmod 644 /etc/pam.d/greetd
systemctl disable --now getty@tty1.service 2>/dev/null || true

cat <<'EOF' > /etc/systemd/system/greetd.service
[Unit]
Description=greetd login manager
After=systemd-user-sessions.service
[Service]
ExecStart=/usr/local/bin/greetd
StandardInput=tty
StandardOutput=tty
StandardError=journal
Restart=always
RestartSec=1
TTYPath=/dev/tty2
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable greetd
systemctl start greetd

# ─────────────────────── XINITRC + AUTOSTART (correct paths) ───────────────────────
echo "[+] Creating .xinitrc and autostart for $USERNAME..."

mkdir -p "$USER_HOME/.config/xorg" "$USER_HOME/.local/bin" "$USER_HOME/.local/share/wallpapers"

cat <<'EOF' > "$USER_HOME/.config/xorg/xinitrc"
#!/bin/sh
# ~/.xinitrc — starts DWM session

setxkbmap us
export PATH="$HOME/.local/bin:$PATH"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export DISPLAY=:0

if command -v gnome-keyring-daemon >/dev/null 2>&1; then
    eval "$(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)"
    export SSH_AUTH_SOCK
fi

if command -v /usr/libexec/polkit-lxqt-authentication-agent-1 >/dev/null 2>&1; then
    /usr/libexec/polkit-lxqt-authentication-agent-1 &
elif command -v /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1; then
    /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
fi

if [ -x "$HOME/.local/bin/autostart" ]; then
    "$HOME/.local/bin/autostart" &
fi

(sleep 2 && "$HOME/.local/bin/dwmstatus") &
exec dwm
EOF

ln -sf "$USER_HOME/.config/xorg/xinitrc" "$USER_HOME/.xinitrc"
chmod +x "$USER_HOME/.config/xorg/xinitrc"

cat <<'EOF' > "$USER_HOME/.local/bin/autostart"
#!/bin/sh
# ~/.local/bin/autostart — startup apps for DWM

if command -v feh >/dev/null 2>&1; then
    feh --bg-fill "$HOME/.local/share/wallpapers/default.jpg" &
fi

if command -v nm-applet >/dev/null 2>&1; then
    pgrep nm-applet >/dev/null || nm-applet &
fi

if command -v blueman-applet >/dev/null 2>&1; then
    pgrep blueman-applet >/dev/null || blueman-applet &
fi

if command -v dunst >/dev/null 2>&1; then
    pgrep dunst >/dev/null || dunst &
fi

if command -v light >/dev/null 2>&1; then
    light -S 40 &
fi

echo "Autostart executed at $(date)" >> "$HOME/.cache/dwm-startup.log"
EOF

chmod +x "$USER_HOME/.local/bin/autostart"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.config" "$USER_HOME/.local"

echo "[+] .xinitrc, autostart, and permissions configured."

echo
echo "✅ All done. Reboot and log in via greetd → DWM should start automatically!"
