#!/bin/bash
#
# Debian Minimal + DWM + ST + DMENU + greetd/tuigreet setup
# For ThinkPad T480s (Intel, no bloat)
# ------------------------------------------------------------
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Please run this script as root (sudo bash setup.sh)"
    exit 1
fi

read -rp "Enter your normal username (to grant sudo privileges): " USERNAME
id "$USERNAME" &>/dev/null || useradd -m -G users "$USERNAME"
usermod -aG sudo "$USERNAME"
echo "[+] $USERNAME added to sudo group."
sleep 1

apt update
apt install -y passwd

# ─────────────────────── BASE TOOLCHAIN ─────────────────────────────
sudo -u "$USERNAME" bash <<'USERBLOCK'
set -e
sudo apt install -y --no-install-recommends \
  build-essential make gcc pkg-config neovim htop unzip git

# ─────────────────────── XORG + INTEL VIDEO ─────────────────────────
sudo apt install -y --no-install-recommends \
  xserver-xorg-core xserver-xorg-video-intel xserver-xorg-input-libinput xinit \
  libx11-dev libxft-dev libxinerama-dev x11-xserver-utils

# ─────────────────────── AUDIO + BLUETOOTH ──────────────────────────
sudo apt install -y --no-install-recommends \
  alsa-utils pulseaudio pulseaudio-module-bluetooth bluez libbluetooth-dev
sudo systemctl enable bluetooth
sudo systemctl start bluetooth

# ─────────────────────── NETWORKMANAGER + IWD ───────────────────────
sudo apt install -y --no-install-recommends network-manager iwd
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
echo -e "[device]\nwifi.backend=iwd" | sudo tee /etc/NetworkManager/NetworkManager.conf >/dev/null
sudo systemctl restart NetworkManager

# ─────────────────────── POLKIT ─────────────────────────────────────
sudo apt install -y --no-install-recommends polkitd pkexec lxqt-policykit

# ─────────────────────── FONTS + UTILITIES ──────────────────────────
sudo apt install -y --no-install-recommends \
  feh lxappearance thunar xclip fonts-dejavu fonts-noto-color-emoji

# ─────────────────────── SUCKLESS SOFTWARE ──────────────────────────
mkdir -p "$HOME/.config"
cd "$HOME/.config"

# ─ dwm ──────────────────────────
if [ ! -d "dwm" ]; then
  git clone https://git.suckless.org/dwm
fi
(cd dwm && sudo make clean install)

# ─ st ───────────────────────────
if [ ! -d "st" ]; then
  git clone https://git.suckless.org/st
fi
(cd st && sudo make clean install)

# ─ dmenu ────────────────────────
if [ ! -d "dmenu" ]; then
  git clone https://git.suckless.org/dmenu
fi
(cd dmenu && sudo make clean install)

# ─────────────────────── DWMSTATUS (custom C) ───────────────────────
mkdir -p "$HOME/src" "$HOME/.local/bin"
if [ ! -f "$HOME/src/dwmstatus-ultra-alsa.c" ]; then
  cat <<'EOF' > "$HOME/src/dwmstatus-ultra-alsa.c"
// dwmstatus-ultra-alsa.c - minimal status bar for DWM
#include <alsa/asoundlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define STR_LEN 256
void readfile(const char *path, char *buf, size_t size){FILE*f=fopen(path,"r");if(!f){buf[0]='\0';return;}if(fgets(buf,size,f)==NULL)buf[0]='\0';fclose(f);size_t l=strlen(buf);if(l>0&&buf[l-1]=='\n')buf[l-1]='\0';}
void get_time_str(char*b,size_t s){time_t n=time(NULL);struct tm *t=localtime(&n);strftime(b,s,"%a %d %b %H:%M",t);}
void get_battery(char*b,size_t s){char c[16],st[32];readfile("/sys/class/power_supply/BAT0/capacity",c,16);readfile("/sys/class/power_supply/BAT0/status",st,32);if(!strlen(c)){snprintf(b,s,"");return;}if(!strncmp(st,"Charging",8))snprintf(b,s,"⚡%s%%",c);else snprintf(b,s,"🔋%s%%",c);}
void get_bt(char*b,size_t s){char v[8];readfile("/sys/class/bluetooth/hci0/connected",v,8);if(strlen(v)&&v[0]=='1')snprintf(b,s,"");else snprintf(b,s," ");}
void get_vol(char*b,size_t s){long mn,mx,v;snd_mixer_t*h;snd_mixer_selem_id_t*i;const char*m="Master",*c="default";snd_mixer_elem_t*e;if(snd_mixer_open(&h,0)<0||snd_mixer_attach(h,c)<0||snd_mixer_selem_register(h,NULL,NULL)<0||snd_mixer_load(h)<0){snprintf(b,s,"VOL:--");if(h)snd_mixer_close(h);return;}snd_mixer_selem_id_malloc(&i);snd_mixer_selem_id_set_index(i,0);snd_mixer_selem_id_set_name(i,m);e=snd_mixer_find_selem(h,i);if(!e){snprintf(b,s,"VOL:--");}else{snd_mixer_selem_get_playback_volume_range(e,&mn,&mx);snd_mixer_selem_get_playback_volume(e,SND_MIXER_SCHN_FRONT_LEFT,&v);double p=((double)(v-mn)/(mx-mn))*100.0;snprintf(b,s,"VOL:%ld%%",(long)p);}snd_mixer_close(h);snd_mixer_selem_id_free(i);}
int main(void){char t[64],bat[32],vol[32],bt[8],stat[STR_LEN],cmd[STR_LEN+50];for(;;){get_time_str(t,64);get_battery(bat,32);get_vol(vol,32);get_bt(bt,8);snprintf(stat,STR_LEN,"%s %s | %s | %s",bt,vol,bat,t);snprintf(cmd,sizeof(cmd),"xsetroot -name \"%s\"",stat);system(cmd);sleep(10);}return 0;}
EOF
fi
sudo apt install -y --no-install-recommends libasound2-dev
gcc -O2 -Wall "$HOME/src/dwmstatus-ultra-alsa.c" -o "$HOME/.local/bin/dwmstatus" -lasound
chmod +x "$HOME/.local/bin/dwmstatus"

# ─────────────────────── TUI LOGIN: GREETD + TUIGREET ───────────────
sudo apt install -y --no-install-recommends cargo libpam0g-dev
cd /usr/local/src
if [ ! -d greetd ]; then
  sudo git clone https://git.sr.ht/~kennylevinsen/greetd
fi
cd greetd
sudo cargo build --release
sudo cp target/release/greetd /usr/local/bin/
cd ..
if [ ! -d tuigreet ]; then
  sudo git clone https://github.com/apognu/tuigreet.git
fi
cd tuigreet
sudo cargo build --release
sudo cp target/release/tuigreet /usr/local/bin/
cd ..

sudo mkdir -p /etc/greetd
sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 2
[default_session]
command = "tuigreet --cmd startx --remember --time"
user = "greeter"
EOF

# Disable getty@tty1 so greetd can take it
sudo systemctl disable --now getty@tty1.service 2>/dev/null || true

# ──────────────  Create PAM configuration for greetd  ──────────────
sudo tee /etc/pam.d/greetd >/dev/null <<'EOF'
# PAM service for greetd (TUI login manager)
auth        include        login
account     include        login
password    include        login
session     include        login
EOF
sudo chmod 644 /etc/pam.d/greetd

sudo tee /etc/systemd/system/greetd.service >/dev/null <<'EOF'
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
sudo systemctl daemon-reload
sudo systemctl enable greetd
sudo systemctl start greetd
# ────────────────────── XINITRC + AUTOSTART CREATION  ──────────────────────
echo "[+] Creating default ~/.xinitrc and autostart scripts..."

# Create X init configuration
mkdir -p "$HOME/.config/xorg" "$HOME/.local/bin" "$HOME/.local/share/wallpapers"

cat <<'EOF' > "$HOME/.config/xorg/xinitrc"
#!/bin/sh
# ~/.xinitrc — starts DWM session for Debian minimal setup

# Keyboard layout
setxkbmap us

# Environment variables
export PATH="$HOME/.local/bin:$PATH"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export DISPLAY=:0

# Start GNOME Keyring (for SSH/app secrets)
if command -v gnome-keyring-daemon >/dev/null 2>&1; then
    eval "$(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)"
    export SSH_AUTH_SOCK
fi

# Start Polkit agent
if command -v /usr/libexec/polkit-lxqt-authentication-agent-1 >/dev/null 2>&1; then
    /usr/libexec/polkit-lxqt-authentication-agent-1 &
elif command -v /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1; then
    /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
fi

# Start autostart script (trays, wallpaper, etc.)
if [ -x "$HOME/.local/bin/autostart" ]; then
    "$HOME/.local/bin/autostart" &
fi

# Delay dwmstatus slightly to avoid starting before X
(sleep 2 && "$HOME/.local/bin/dwmstatus") &

exec dwm
EOF

ln -sf "$HOME/.config/xorg/xinitrc" "$HOME/.xinitrc"
chmod +x "$HOME/.config/xorg/xinitrc"

# ────────────────────── AUTOSTART  ──────────────────────
cat <<'EOF' > "$HOME/.local/bin/autostart"
#!/bin/sh
# ~/.local/bin/autostart — background applications for DWM

# Wallpaper
if command -v feh >/dev/null 2>&1; then
    feh --bg-fill "$HOME/.local/share/wallpapers/default.jpg" &
fi

# NetworkManager tray applet
if command -v nm-applet >/dev/null 2>&1; then
    pgrep nm-applet >/dev/null || nm-applet &
fi

# Bluetooth applet
if command -v blueman-applet >/dev/null 2>&1; then
    pgrep blueman-applet >/dev/null || blueman-applet &
fi

# Notifications (optional)
if command -v dunst >/dev/null 2>&1; then
    pgrep dunst >/dev/null || dunst &
fi

# Example screen brightness
if command -v light >/dev/null 2>&1; then
    light -S 40 &
fi

echo "Autostart executed at $(date)" >> "$HOME/.cache/dwm-startup.log"
EOF

chmod +x "$HOME/.local/bin/autostart"
echo "[+] ~/.xinitrc and autostart created and linked."

USERBLOCK



echo
echo "✅ All done. Reboot and log in via greetd → DWM should start automatically!"
