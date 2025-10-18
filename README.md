# Jamie’s Debian DWM Workstation Setup

This repository contains a self‑contained script for building a lightweight Debian desktop environment using **DWM**, **ST**, and **dmenu**.  
It also installs and configures **greetd + tuigreet**, **NetworkManager + iwd**, **PulseAudio + Bluetooth**, **Polkit**, and a custom **dwmstatus** bar.  

This setup is especially suited for ThinkPads (tested on the T480s with Intel graphics) and for anyone wanting a minimal, manually controlled system.

---

## Overview

**Installed software:**
- DWM, ST, and dmenu (from suckless.org)
- greetd + tuigreet (TUI login manager)
- ALSA, PulseAudio, Bluetooth (bluez)
- NetworkManager + iwd (Wi‑Fi support)
- Polkit + LXQt Polkit authentication agent
- GNOME Keyring for SSH and password management
- Custom C‑based `dwmstatus` bar (battery, volume, Bluetooth, time)
- Xorg with Intel video drivers
- feh (wallpaper), Thunar (file manager), lxappearance (themes)

---

## 1. Boot the Debian ISO

1. Download the **firmware‑included Debian Netinst ISO** (Debian 12 "Bookworm" or newer):  
   https://cdimage.debian.org/images/unofficial/non-free/images-including-firmware/current/amd64/iso-cd/

2. Burn it to a USB drive or attach it as a virtual ISO.

3. Boot your computer or VM from the ISO.

4. Choose **"Graphical install"** or **"Install"** from the Debian boot menu.

---

## 2. Follow the Debian Installer

During installation, use these choices for the cleanest minimal setup:

1. **Language, location, keyboard:** configure as usual.  
2. **Network setup:** connect via Wi‑Fi or Ethernet.  
3. **User accounts:**  
   - Set a root password (optional).  
   - Create your normal user account and password.  
4. **Partitioning:**  
   - Choose “Guided – use entire disk”; `ext4` is fine.  
5. **Software selection:**  
   - At the “Software selection” screen, check only:  
     - `[*] standard system utilities`  
     - `[*] network manager` (if listed)
   - Uncheck all desktop environments (GNOME, XFCE, etc.).
6. **Install the GRUB bootloader** when prompted.
7. Finish the installation and reboot into a clean, text‑only Debian system.

---

## 3. Connect to Wi‑Fi Manually (if needed)

If NetworkManager was not installed or you want to connect manually, you can use **`iw`** and **`wpa_supplicant`**.

### 3.1 Verify the wireless interface

List devices:
```bash
ip link
```

Output should show something like `wlan0` or `wlp2s0`.  
Bring it up if necessary:
```bash
ip link set wlan0 up
```

### 3.2 Scan for networks
```bash
iw dev wlan0 scan | grep SSID
```

Pick the SSID you want to connect to.

### 3.3 Create a WPA configuration
```bash
wpa_passphrase "YourSSID" "YourPassword" > /etc/wpa_supplicant.conf
```

The file should look like:
```text
network={
    ssid="YourSSID"
    #psk="YourPassword"
    psk=0e8c5e0dc8bba0bd...
}
```

### 3.4 Start wpa_supplicant
```bash
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
```

Check the link:
```bash
iw dev wlan0 link
```

### 3.5 Get an IP address
```bash
dhclient wlan0
```

Test connectivity:
```bash
ping -c 3 debian.org
```


---

## 4. Update the System

After confirming network access, update your system packages.

Log in as `root` or a sudo‑enabled user:

```bash
apt update
apt upgrade -y
```

---

## 5. Install Basic Tools

Install the essentials needed to download and run this setup:

```bash
apt install -y sudo git curl wget ca-certificates
```

If your user is not already a sudoer:

```bash
usermod -aG sudo yourusername
```

---

## 6. Clone the Repository

```bash
git clone https://github.com/JamieMPerks/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

---

## 7. Run the Setup Script

```bash
chmod +x setup.sh
sudo bash setup.sh
```

During setup you will be prompted for your normal username.

The script will:
- Create the user if necessary and add it to the **sudo** group.  
- Install all required development, Xorg, and multimedia packages.  
- Build and install DWM, ST, dmenu, and your custom `dwmstatus`.  
- Configure **greetd + tuigreet** for TUI login.  
- Configure audio, Bluetooth, NetworkManager, and Polkit.  
- Generate default `~/.xinitrc` and `~/.local/bin/autostart` scripts.

---

## 8. Reboot

```bash
sudo reboot
```

After reboot:
1. The **tuigreet** login screen appears.  
2. Log in with your username and password.  
3. DWM starts automatically.

---

## 9. Basic DWM Usage

**Default key bindings:**
| Action | Key combo |
|---------|------------|
| Open terminal | `Alt + Shift + Enter` |
| Run dmenu | `Alt + p` |
| Close window | `Alt + Shift + c` |
| Quit DWM | `Alt + Shift + q` |

**Status bar:**  
Battery, volume, Bluetooth, and time update every 10 seconds using the custom `dwmstatus` program.

---

## 10. Maintenance and Rebuilding

To pull the latest configuration and rebuild:

```bash
cd ~/.dotfiles
git pull
sudo bash setup.sh
```

To rebuild individual components:

```bash
cd ~/.config/dwm && sudo make clean install
cd ~/.config/st && sudo make clean install
cd ~/.config/dmenu && sudo make clean install
```

---

## Repository

**GitHub:**  
[https://github.com/JamieMPerks/dotfiles.git](https://github.com/JamieMPerks/dotfiles.git)

Author: Jamie M. Perks  
License: MIT — free to use and modify
