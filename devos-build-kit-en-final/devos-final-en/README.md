# DevOS — Minimal Linux OS Based on Fedora/RPM

```
  ██████╗ ███████╗██╗   ██╗ ██████╗ ███████╗
  ██╔══██╗██╔════╝██║   ██║██╔═══██╗██╔════╝
  ██║  ██║█████╗  ██║   ██║██║   ██║███████╗
  ██║  ██║██╔══╝  ╚██╗ ██╔╝██║   ██║╚════██║
  ██████╔╝███████╗ ╚████╔╝ ╚██████╔╝███████║
  ╚═════╝ ╚══════╝  ╚═══╝   ╚═════╝ ╚══════╝

  DevOS 1.0 — Fedora-based Desktop
```

**DevOS** is a lightweight, fully functional desktop OS built from scratch on Fedora 43/RPM using XFCE as the desktop environment. It produces a **Live UEFI-bootable ISO**.

---

## ⚠️ Version Requirement — IMPORTANT

> **This project was developed and tested on Fedora 43.**
> The machine where you build the ISO **must be running Fedora 43**.

```bash
cat /etc/fedora-release
# Should say: Fedora release 43 (...)
```

---

## What's Included

| Component      | Details                            |
|----------------|------------------------------------|
| Base           | Fedora 43 / RPM                    |
| Kernel         | Linux 6.x (Fedora 43)              |
| Init           | systemd                            |
| Desktop        | XFCE 4                             |
| Login          | Autologin via .bash_profile        |
| Browser        | Chromium (VM-optimized)            |
| File manager   | Thunar                             |
| Terminal       | XFCE Terminal                      |
| Editor         | Mousepad                           |
| Theme          | Greybird + Papirus Icons           |
| Wallpaper      | Custom DevOS SVG wallpaper         |
| ISO            | Live UEFI (no installation needed) |

---

## Build System Requirements

- **Distro:** Fedora 43 (required)
- **RAM:** at least 4GB free
- **Disk:** at least 15GB free in `$HOME`
- **CPU:** x86_64
- **Internet** active during build (~1.5GB download)
- **Privileges:** sudo or root

---

## Project Structure

```
devos/
├── README.md
└── scripts/
    ├── 00-clean.sh              ← Cleanup / reset
    ├── 01-build-rootfs.sh       ← Base system + XFCE + all config
    ├── 02-configure-desktop.sh  ← Theme, panel, greeter
    ├── 03-build-iso.sh          ← Builds the final ISO
    └── devos-install.sh         ← (Reserved for future versions)
```

---

## Step by Step: Building DevOS

### STEP 0 — Prepare

```bash
unzip devos-build-kit-en-final.zip
cd devos-final-en
chmod +x scripts/*.sh
cat /etc/fedora-release   # verify Fedora 43
```

### STEP 1 — Build the Root Filesystem

```bash
sudo bash scripts/01-build-rootfs.sh
```

**Duration:** 20–40 minutes (~1.2GB download).

**What it does:**
- Installs build tools on the host
- Creates `~/devos-build/rootfs/` with Fedora 43
- Installs XFCE 4, Chromium, Thunar, Terminal, Mousepad
- Creates `kiosk` user (password: `devos`)
- Copies vmlinuz to `/boot/` if only in `/usr/lib/modules/`
- Configures autologin via `.bash_profile` + `.xinitrc`
- Disables plymouth completely
- Sets `graphical.target` as default
- Generates DevOS SVG wallpaper
- Configures `xfce4-desktop.xml` with VirtualBox's 3 monitor names

**Verify:**
```bash
sudo ls /root/devos-build/rootfs/boot/vmlinuz*
sudo grep "kiosk" /root/devos-build/rootfs/etc/passwd
sudo cat /root/devos-build/rootfs/home/kiosk/.xinitrc
```

### STEP 2 — Configure Desktop

```bash
sudo bash scripts/02-configure-desktop.sh
```

**Duration:** ~1 minute. Configures XFCE theme, panel, and greeter.

### STEP 3 — Build the ISO

```bash
sudo bash scripts/03-build-iso.sh
```

**Duration:** 20–45 minutes (XZ compression).

When done:
```
╔══════════════════════════════════════════════════╗
║           ISO SUCCESSFULLY GENERATED             ║
║  File   : devos-desktop.iso                      ║
║  Size   : ~1.5GB                                 ║
╚══════════════════════════════════════════════════╝
```

Copy to Downloads:
```bash
sudo cp /root/devos-build/output/devos-desktop.iso ~/Downloads/
sudo chown $USER:$USER ~/Downloads/devos-desktop.iso
```

---

## VirtualBox Configuration

| Setting | Value |
|---------|-------|
| RAM | 2048 MB |
| System → Motherboard | ✅ **Enable EFI** (required) |
| Display → Controller | **VBoxSVGA** (not VMSVGA) |
| Video RAM | 64 MB |
| 3D Acceleration | ❌ Disable |
| Network | NAT |

> ⚠️ Without EFI enabled the ISO will not boot.
> ⚠️ Use VBoxSVGA, not VMSVGA — VMSVGA causes vmwgfx errors.

---

## QEMU/KVM Configuration (recommended)

```bash
# Create virtual disk
qemu-img create -f qcow2 ~/devos-disk.qcow2 20G

# Copy OVMF vars
cp /usr/share/edk2/ovmf/OVMF_VARS.fd ~/devos-ovmf-vars.fd

# Boot Live
qemu-system-x86_64 \
    -name "DevOS" -m 2048 -smp 2 -enable-kvm \
    -drive file=/usr/share/edk2/ovmf/OVMF_CODE.fd,if=pflash,format=raw,readonly=on \
    -drive file=$HOME/devos-ovmf-vars.fd,if=pflash,format=raw \
    -cdrom ~/Downloads/devos-desktop.iso \
    -boot d -vga virtio -display gtk \
    -device virtio-net-pci,netdev=net0 -netdev user,id=net0
```

> If KVM is blocked by VirtualBox conflict:
> ```bash
> sudo modprobe -r vboxdrv vboxnetflt vboxnetadp
> sudo modprobe kvm_intel
> ```

---

## System Users

| User | Password | Description |
|------|----------|-------------|
| `kiosk` | `devos` | Main user (autologin) |
| `root` | `devos123` | Root |

---

## Troubleshooting

### ISO doesn't boot in VirtualBox
→ **Settings → System → Motherboard → ✅ Enable EFI**

### Black screen / vmwgfx errors
→ Change graphics controller to **VBoxSVGA** (not VMSVGA)

### Desktop doesn't load, stuck at kernel console
→ Press **Alt+F2**, login as root, run:
```bash
systemctl start lightdm
```
If this fixes it temporarily, the squashfs doesn't have the latest changes — rebuild with script 03.

### plymouth-quit-wait blocks boot for 20+ minutes
→ Already disabled in the scripts. If it persists:
```bash
sudo ln -sf /dev/null /root/devos-build/rootfs/etc/systemd/system/plymouth-quit-wait.service
```
Then rebuild squashfs and ISO.

### Wallpaper shows Fedora instead of DevOS
→ Inside the Live system, run:
```bash
for m in monitorNone-1 monitorscreen monitorVirtual-1; do
    xfconf-query -c xfce4-desktop \
        -p /backdrop/screen0/${m}/workspace0/last-image \
        -s /usr/share/backgrounds/devos/wallpaper.svg
done
xfdesktop --reload
```

### KVM not available (VirtualBox conflict)
```bash
sudo modprobe -r vboxdrv vboxnetflt vboxnetadp
sudo modprobe kvm_intel
```

### Fast ISO rebuild (without rebuilding rootfs)
```bash
sudo bash scripts/00-clean.sh   # option 1
sudo bash scripts/03-build-iso.sh
```

---

## All Bugs Found and Fixed

| # | Error | Root cause | Fix applied |
|---|-------|-----------|-------------|
| 1 | `No match for argument: fedora-release` | Missing `--use-host-config` in dnf | Added to `DNF_OPTS` |
| 2 | Hardcoded Fedora 41 version | Static variable | Auto-detection with `rpm -E %fedora` |
| 3 | `chpasswd: could not open /etc/passwd` | `/proc` not mounted in chroot | `-t proc` mount + direct `sed` fallback |
| 4 | `vmlinuz-6.x: No such file` | Fedora 43 puts it in `/usr/lib/modules/` | Auto-copied to `/boot/` |
| 5 | `group 'plugdev' does not exist` | Doesn't exist in Fedora | Removed from `usermod` |
| 6 | `greybird-gtk2/gtk3-theme: No match` | Renamed in Fedora 43 | Changed to `greybird-light/dark-theme` |
| 7 | `polkit-gnome: No match` | Doesn't exist in Fedora 43 | Changed to `xfce-polkit` |
| 8 | `chpasswd` fails with shadow at 000 permissions | RPM installs shadow unreadable | `chmod 600` + direct `sed` fallback |
| 9 | `systemctl enable` unreliable in chroot | `/proc` not fully available | Direct systemd symlinks |
| 10 | System boots to console instead of desktop | `graphical.target` was not the default | Symlink `default.target → graphical.target` |
| 11 | `plymouth-quit-wait` blocked boot 20+ min | Plymouth waiting for display manager | Disabled with `/dev/null` |
| 12 | XFCE didn't start automatically | Missing `.xinitrc` and `.bash_profile` | Added with `exec xfce4-session` and `exec startx` |
| 13 | Fedora wallpaper instead of DevOS | `xfce4-desktop.xml` missing VirtualBox monitor names | XML updated with `monitorNone-1`, `monitorscreen`, `monitorVirtual-1` |
| 14 | `dracut-initqueue` hung for 20+ min | `rd.live.overlay.overlayfs` fails with `/dev/shm` in VirtualBox | Removed from grub.cfg |
| 15 | `vmwgfx` errors in VirtualBox | vmwgfx driver is for VMware, not VirtualBox | `nomodeset` in grub.cfg + VBoxSVGA controller |
| 16 | Plymouth in initramfs blocked boot | Plymouth module in dracut conflicted | `--omit plymouth` in dracut |

---

## Quick Reference

```bash
# Full build
sudo bash scripts/01-build-rootfs.sh
sudo bash scripts/02-configure-desktop.sh
sudo bash scripts/03-build-iso.sh

# ISO rebuild only
sudo bash scripts/00-clean.sh    # option 1
sudo bash scripts/03-build-iso.sh

# Enter rootfs manually
sudo systemd-nspawn -D /root/devos-build/rootfs /bin/bash

# Check rootfs size
sudo du -sh /root/devos-build/rootfs

# Check generated ISO
ls -lh /root/devos-build/output/devos-desktop.iso
```

---

*DevOS — Fedora 43 / RPM · systemd · XFCE · dracut · xorriso*
