# Jamie’s Debian DWM Workstation Setup

This repository contains a self-contained script for building a lightweight Debian desktop environment using **DWM**, **ST**, and **dmenu**.  
It also installs and configures **greetd + tuigreet**, **NetworkManager + iwd**, **PulseAudio + Bluetooth**, **Polkit**, and a custom **dwmstatus** bar.  

This setup is especially suited for ThinkPads (tested on the T480s with Intel graphics) and for anyone wanting a minimal, manually controlled system.

---

## Overview

**Installed software:**
- DWM, ST, and dmenu (from suckless.org)
- greetd + tuigreet (TUI login manager)
- ALSA, PulseAudio, Bluetooth (bluez)
- NetworkManager + iwd (Wi-Fi support)
- Polkit + LXQt Polkit authentication agent
- GNOME Keyring for SSH and password management
- Custom C-based `dwmstatus` bar (battery, volume, Bluetooth, time)
- Xorg with Intel video drivers
- feh (wallpaper), Thunar (file manager), lxappearance (themes)

---

## Installation Guide

### 1. Boot the Debian ISO

1. Download the **Debian Netinst ISO** (Debian 12 "Bookworm" or newer)  
   https://www.debian.org/distrib/netinst

2. Burn it to a USB drive or attach it as a virtual ISO.

3. Boot your computer or VM from the ISO.

4. Choose **"Graphical install"** or **"Install"** from the Debian boot menu.

---

### 2. Follow the Debian installer

During installation, use these choices for the cleanest minimal setup:

1. **Language, location, keyboard:** configure as usual.  
2. **Network setup:** connect via Ethernet or Wi‑Fi if available.  
3. **User accounts:**
   - Set a root password (optional).
   - Create your regular user account and password.
4. **Partitioning:**  
   - Choose “Guided – use entire disk”; ext4 is fine.
5. **Software selection:**  
   - At the “Software selection” screen, **deselect everything** except:
     - “standard system utilities”
   - Do **not** install “Debian desktop environment,” GNOME, Xfce, or others.
6. **Install the GRUB bootloader** when prompted.
7. Finish installation and reboot into a clean, text‑only Debian system.

---

### 3. Update the base system

Log in as `root` (or your user with `sudo` access):

```bash
apt update
apt upgrade -y
```

---

### 4. Install basic tools required to fetch this setup

```bash
apt install -y sudo git curl wget ca-certificates
```

If your regular user account isn’t already in the sudo group, add it:

```bash
usermod -aG sudo yourusername
```

---

### 5. Clone the configuration repository

```bash
git clone https://github.com/JamieMPerks/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

---

### 6. Run the setup script

```bash
chmod +x setup.sh
sudo bash setup.sh
```

During setup, you will be prompted to enter your username.  
The script will:
- Create the user if needed.
- Add the user to the `sudo` group.
- Install all build tools and dependencies.
- Build DWM, ST, dmenu, and the custom `dwmstatus` binary.
- Configure greetd + tuigreet for TUI login.
- Set up audio, Bluetooth, NetworkManager, and Polkit.
- Generate `~/.xinitrc` and `~/.local/bin/autostart`.

---

### 7. Reboot

```bash
sudo reboot
```

After reboot:
- You will see the **tuigreet** login screen.
- Log in with your username and password.
- DWM will start automatically.

---

## Using the System

**Default DWM key bindings:**
- `Alt + Shift + Enter` — open a terminal (ST)
- `Alt + d` — run dmenu
- `Alt + Shift + c` — close window
- `Alt + Shift + q` — log out

**Status bar updates:**  
Battery, volume, Bluetooth, and time refresh every 10 seconds through `dwmstatus`.

---

## Maintenance & Rebuilding

To pull the latest changes and rebuild everything:

```bash
cd ~/.dotfiles
git pull
sudo bash setup.sh
```

Or rebuild individual components:

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
License: MIT (feel free to reuse and modify)

---
