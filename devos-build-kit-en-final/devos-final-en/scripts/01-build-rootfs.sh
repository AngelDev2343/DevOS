#!/bin/bash
# =============================================================================
# DevOS — Script 01: Construcción del Root Filesystem
# Tested on Fedora 43 / RPM
#
# BUGS FIXED (encontrados en producción):
# 1.  --use-host-config faltaba → dnf no encontraba repos en installroot
# 2.  Versión Fedora hardcodeada → ahora se detecta con rpm -E
# 3.  chpasswd fallaba → /proc no montado; usando -t proc + fallback sed
# 4.  vmlinuz no en /boot en Fedora 43 → copiado desde /usr/lib/modules/
# 5.  plugdev no existe en Fedora → eliminado del usermod
# 6.  greybird-gtk2/gtk3-theme renombrados → greybird-light/dark-theme
# 7.  polkit-gnome no existe en Fedora 43 → xfce-polkit
# 8.  shadow con permisos 000 → chmod 600 temporal + sed directo
# 9.  systemctl en chroot poco confiable → direct symlinks
# 10. graphical.target no era el default → symlink a default.target
# 11. plymouth bloqueaba arranque → deshabilitado con /dev/null
# 12. .xinitrc y .bash_profile faltaban → agregados para autologin X
# 13. wallpaper no cargaba → xfce4-desktop.xml con los 3 monitores de VirtualBox
# 14. rd.live.overlay.overlayfs causaba cuelgue en dracut → eliminado del grub
# =============================================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
die()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

export DEVOS_BUILD="${DEVOS_BUILD:-$HOME/devos-build}"
export ROOTFS="$DEVOS_BUILD/rootfs"

[[ $EUID -ne 0 ]] && die "Run with sudo or as root."
command -v dnf &>/dev/null || die "dnf no encontrado. You need Fedora 43."
command -v rpm &>/dev/null || die "rpm no encontrado."

# FIX #2: detectar versión real de Fedora
FEDORA_RELEASE=$(rpm -E %fedora 2>/dev/null)
[[ -z "$FEDORA_RELEASE" || "$FEDORA_RELEASE" == "%fedora" ]] && \
    FEDORA_RELEASE=$(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
[[ -z "$FEDORA_RELEASE" ]] && FEDORA_RELEASE=43

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   DevOS Build — Fase 01: Root Filesystem  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
log "Host Fedora version: $FEDORA_RELEASE"
[[ "$FEDORA_RELEASE" != "43" ]] && \
    warn "Tested on Fedora 43. You are using $FEDORA_RELEASE — may work but not guaranteed."

# ── Herramientas del host ─────────────────────────────────────────────────────
log "Installing build tools..."
for pkg in squashfs-tools grub2-tools grub2-efi-x64 grub2-efi-x64-modules \
           grub2-pc-modules xorriso dosfstools dracut dracut-live \
           dracut-squash systemd-container edk2-ovmf; do
    dnf install -y "$pkg" &>/dev/null && log "  OK: $pkg" || warn "  skipped: $pkg"
done
ok "Build tools ready."

mkdir -p "$DEVOS_BUILD"/{rootfs,iso-stage,output,scripts}
mkdir -p "$DEVOS_BUILD/iso-stage"/{EFI/BOOT,boot/grub,LiveOS}
ok "Directories created."

# FIX #1: --use-host-config obligatorio
DNF_OPTS="--installroot=$ROOTFS --releasever=$FEDORA_RELEASE --use-host-config --setopt=install_weak_deps=False --nodocs -y"

# ── Sistema base ──────────────────────────────────────────────────────────────
log "Installing Fedora base system $FEDORA_RELEASE (~800MB, 10-20 min)..."
dnf install $DNF_OPTS fedora-release \
    || die "No se pudo instalar fedora-release. Check your connection."

for pkg in systemd systemd-udev passwd shadow-utils util-linux coreutils bash \
           dnf glibc glibc-minimal-langpack NetworkManager iproute iputils \
           procps-ng psmisc less vim-minimal sudo openssh-server \
           kernel kernel-core linux-firmware dracut dracut-live dracut-network; do
    dnf install $DNF_OPTS "$pkg" &>/dev/null && log "  OK: $pkg" || warn "  skipped: $pkg"
done
dnf install $DNF_OPTS dracut-squash &>/dev/null || warn "dracut-squash no disponible (normal en Fedora 43+)."
ok "Sistema base instalado."

# FIX #4: vmlinuz en Fedora 43 va a /usr/lib/modules/, copiarlo a /boot/
log "Verificando vmlinuz..."
KERNEL_VER=$(ls "$ROOTFS/lib/modules/" 2>/dev/null | grep -v rescue | sort -V | tail -1)
if [[ -n "$KERNEL_VER" && ! -f "$ROOTFS/boot/vmlinuz-${KERNEL_VER}" ]]; then
    VMLINUZ_SRC="$ROOTFS/usr/lib/modules/${KERNEL_VER}/vmlinuz"
    [[ -f "$VMLINUZ_SRC" ]] && \
        cp "$VMLINUZ_SRC" "$ROOTFS/boot/vmlinuz-${KERNEL_VER}" && \
        ok "vmlinuz copied to /boot/ (Fedora 43 fix)" || \
        warn "vmlinuz not found"
else
    ok "vmlinuz already in /boot/"
fi

# ── XFCE + apps ───────────────────────────────────────────────────────────────
log "Installing XFCE (~400MB)..."
dnf install $DNF_OPTS @xfce-desktop || die "Failed to install @xfce-desktop."

# FIX #6 y #7: nombres correctos en Fedora 43
for pkg in xfce4-terminal xfce4-taskmanager xfce4-screenshooter \
           xfce4-notifyd xfce4-power-manager \
           thunar thunar-archive-plugin thunar-volman mousepad chromium \
           lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
           network-manager-applet adwaita-icon-theme papirus-icon-theme \
           greybird-light-theme greybird-dark-theme \
           fonts-filesystem google-noto-sans-fonts google-noto-mono-fonts \
           gvfs udisks2 polkit xfce-polkit \
           plymouth plymouth-theme-spinner; do
    dnf install $DNF_OPTS "$pkg" &>/dev/null && log "  OK: $pkg" || warn "  skipped: $pkg"
done
ok "XFCE instalado."

# ── Configuración básica ──────────────────────────────────────────────────────
log "Configuring system..."
echo "devos" > "$ROOTFS/etc/hostname"
echo "LANG=en_US.UTF-8" > "$ROOTFS/etc/locale.conf"
ln -sf /usr/share/zoneinfo/UTC "$ROOTFS/etc/localtime" 2>/dev/null || true

cat > "$ROOTFS/etc/os-release" <<'OSREL'
NAME="DevOS"
VERSION="1.0"
ID=devos
ID_LIKE=fedora
VERSION_ID=1
PRETTY_NAME="DevOS 1.0 (Fedora-based Desktop)"
ANSI_COLOR="1;36"
HOME_URL="https://localhost"
OSREL

cat > "$ROOTFS/etc/issue" <<'ISSUE'

  ██████╗ ███████╗██╗   ██╗ ██████╗ ███████╗
  ██╔══██╗██╔════╝██║   ██║██╔═══██╗██╔════╝
  ██║  ██║█████╗  ██║   ██║██║   ██║███████╗
  ██║  ██║██╔══╝  ╚██╗ ██╔╝██║   ██║╚════██║
  ██████╔╝███████╗ ╚████╔╝ ╚██████╔╝███████║
  ╚═════╝ ╚══════╝  ╚═══╝   ╚═════╝ ╚══════╝

  DevOS 1.0 — Fedora-based Desktop | Kernel \r — \l

ISSUE
ok "Sistema configurado."

# ── Usuario kiosk ─────────────────────────────────────────────────────────────
log "Creating kiosk user..."

# FIX #3: mount with -t proc
mount -t proc proc "$ROOTFS/proc" 2>/dev/null || true
mount -t sysfs sysfs "$ROOTFS/sys" 2>/dev/null || true
mount --bind /dev "$ROOTFS/dev" 2>/dev/null || true
mount --bind /run "$ROOTFS/run" 2>/dev/null || true

if chroot "$ROOTFS" /bin/bash -c "echo 'root:devos123' | chpasswd" 2>/dev/null; then
    chroot "$ROOTFS" /bin/bash -c "
        useradd -m -s /bin/bash -c 'DevOS User' kiosk 2>/dev/null || true
        echo 'kiosk:devos' | chpasswd
        usermod -aG wheel,audio,video kiosk
    " && ok "Users created with chpasswd."
else
    # FIX #8: fallback directo
    warn "chpasswd unavailable — using direct method..."
    chmod 600 "$ROOTFS/etc/shadow"
    ROOT_HASH=$(openssl passwd -6 "devos123")
    KIOSK_HASH=$(openssl passwd -6 "devos")
    sed -i "s|^root:[^:]*:|root:$ROOT_HASH:|" "$ROOTFS/etc/shadow"
    if ! grep -q "^kiosk:" "$ROOTFS/etc/passwd"; then
        echo "kiosk:x:1000:1000:DevOS User:/home/kiosk:/bin/bash" >> "$ROOTFS/etc/passwd"
        echo "kiosk:$KIOSK_HASH:20000:0:99999:7:::" >> "$ROOTFS/etc/shadow"
        echo "kiosk:x:1000:" >> "$ROOTFS/etc/group"
        mkdir -p "$ROOTFS/home/kiosk"
        chown 1000:1000 "$ROOTFS/home/kiosk"
        chmod 700 "$ROOTFS/home/kiosk"
    fi
    # FIX #5: no plugdev
    grep -q "kiosk" <<< "$(grep "^wheel:" "$ROOTFS/etc/group")" || \
        sed -i 's/^wheel:x:10:/wheel:x:10:kiosk/' "$ROOTFS/etc/group"
    grep -q "kiosk" <<< "$(grep "^audio:" "$ROOTFS/etc/group")" || \
        sed -i 's/^audio:x:63:/audio:x:63:kiosk/' "$ROOTFS/etc/group"
    grep -q "kiosk" <<< "$(grep "^video:" "$ROOTFS/etc/group")" || \
        sed -i 's/^video:x:39:/video:x:39:kiosk/' "$ROOTFS/etc/group"
    chmod 000 "$ROOTFS/etc/shadow"
    ok "Users created via direct method."
fi

umount "$ROOTFS/proc" 2>/dev/null || true
umount "$ROOTFS/sys"  2>/dev/null || true
umount "$ROOTFS/dev"  2>/dev/null || true
umount "$ROOTFS/run"  2>/dev/null || true

echo "kiosk ALL=(ALL) NOPASSWD: ALL" > "$ROOTFS/etc/sudoers.d/kiosk"
chmod 440 "$ROOTFS/etc/sudoers.d/kiosk"
ok "kiosk user ready (password: devos)."

# ── Servicios ─────────────────────────────────────────────────────────────────
log "Enabling services..."
# FIX #9: direct symlinks
mkdir -p "$ROOTFS/etc/systemd/system/multi-user.target.wants"
mkdir -p "$ROOTFS/etc/systemd/system/graphical.target.wants"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
    "$ROOTFS/etc/systemd/system/multi-user.target.wants/NetworkManager.service" 2>/dev/null || true
ln -sf /usr/lib/systemd/system/lightdm.service \
    "$ROOTFS/etc/systemd/system/display-manager.service" 2>/dev/null || true
ln -sf /usr/lib/systemd/system/lightdm.service \
    "$ROOTFS/etc/systemd/system/graphical.target.wants/lightdm.service" 2>/dev/null || true
ln -sf /usr/lib/systemd/system/udisks2.service \
    "$ROOTFS/etc/systemd/system/graphical.target.wants/udisks2.service" 2>/dev/null || true

# FIX #10: graphical.target as default
ln -sf /usr/lib/systemd/system/graphical.target \
    "$ROOTFS/etc/systemd/system/default.target"

# FIX #11: disable plymouth completely
ln -sf /dev/null "$ROOTFS/etc/systemd/system/plymouth-quit-wait.service"
ln -sf /dev/null "$ROOTFS/etc/systemd/system/plymouth-quit.service"
ln -sf /dev/null "$ROOTFS/etc/systemd/system/plymouth-start.service"

ok "Services enabled, plymouth disabled."

# ── Perfil XFCE de kiosk ──────────────────────────────────────────────────────
log "Configuring XFCE profile..."
KIOSK_HOME="$ROOTFS/home/kiosk"
mkdir -p "$KIOSK_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$KIOSK_HOME/Desktop"

# FIX #12: .xinitrc y .bash_profile para autologin X sin LightDM
cat > "$KIOSK_HOME/.xinitrc" <<'XINITRC'
exec xfce4-session
XINITRC

cat > "$KIOSK_HOME/.bash_profile" <<'BASHPROFILE'
if [[ -z $DISPLAY && $XDG_VTNR -eq 1 ]]; then
    exec startx
fi
BASHPROFILE

# FIX #13: xfce4-desktop.xml con los 3 monitores que usa VirtualBox
cat > "$KIOSK_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" <<'DESKTOPXML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorNone-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/devos/wallpaper.svg"/>
        </property>
      </property>
      <property name="monitorscreen" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/devos/wallpaper.svg"/>
        </property>
      </property>
      <property name="monitorVirtual-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/devos/wallpaper.svg"/>
        </property>
      </property>
    </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
    <property name="file-icons" type="empty">
      <property name="show-home"       type="bool" value="true"/>
      <property name="show-filesystem" type="bool" value="false"/>
      <property name="show-removable"  type="bool" value="true"/>
      <property name="show-trash"      type="bool" value="true"/>
    </property>
  </property>
</channel>
DESKTOPXML

# Correct permissions
chown -R 1000:1000 "$KIOSK_HOME"
ok "Perfil XFCE configurado."

# ── Fondo de pantalla ─────────────────────────────────────────────────────────
log "Generating DevOS wallpaper..."
mkdir -p "$ROOTFS/usr/share/backgrounds/devos"
cat > "$ROOTFS/usr/share/backgrounds/devos/wallpaper.svg" <<'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%"   stop-color="#0d0d1a"/>
      <stop offset="45%"  stop-color="#1a1a3e"/>
      <stop offset="100%" stop-color="#0a0a1f"/>
    </linearGradient>
    <filter id="blur"><feGaussianBlur stdDeviation="40"/></filter>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <ellipse cx="960" cy="540" rx="500" ry="300" fill="#3344cc" opacity="0.12" filter="url(#blur)"/>
  <g stroke="#3355aa" stroke-opacity="0.07" stroke-width="1">
    <line x1="0" y1="135" x2="1920" y2="135"/><line x1="0" y1="270" x2="1920" y2="270"/>
    <line x1="0" y1="405" x2="1920" y2="405"/><line x1="0" y1="540" x2="1920" y2="540"/>
    <line x1="0" y1="675" x2="1920" y2="675"/><line x1="0" y1="810" x2="1920" y2="810"/>
    <line x1="192" y1="0" x2="192" y2="1080"/><line x1="384" y1="0" x2="384" y2="1080"/>
    <line x1="576" y1="0" x2="576" y2="1080"/><line x1="768" y1="0" x2="768" y2="1080"/>
    <line x1="960" y1="0" x2="960" y2="1080"/><line x1="1152" y1="0" x2="1152" y2="1080"/>
    <line x1="1344" y1="0" x2="1344" y2="1080"/><line x1="1536" y1="0" x2="1536" y2="1080"/>
  </g>
  <rect x="0" y="0" width="1920" height="2" fill="#4466ff" opacity="0.4"/>
  <circle cx="100" cy="100" r="60" fill="none" stroke="#4466ff" stroke-width="1" opacity="0.15"/>
  <circle cx="1820" cy="980" r="80" fill="none" stroke="#4466ff" stroke-width="1" opacity="0.12"/>
  <text x="960" y="490" font-family="monospace" font-size="110" font-weight="bold"
        fill="#ffffff" fill-opacity="0.92" text-anchor="middle" letter-spacing="8">DevOS</text>
  <text x="960" y="548" font-family="monospace" font-size="20" fill="#7799dd"
        fill-opacity="0.75" text-anchor="middle" letter-spacing="4">MINIMAL DESKTOP  ·  FEDORA-BASED  ·  v1.0</text>
  <line x1="680" y1="572" x2="1240" y2="572" stroke="#4466ff" stroke-width="1" opacity="0.35"/>
  <circle cx="680" cy="572" r="3" fill="#4466ff" opacity="0.5"/>
  <circle cx="960" cy="572" r="3" fill="#4466ff" opacity="0.5"/>
  <circle cx="1240" cy="572" r="3" fill="#4466ff" opacity="0.5"/>
  <text x="1880" y="1060" font-family="monospace" font-size="13" fill="#4466ff"
        fill-opacity="0.4" text-anchor="end">DevOS 1.0</text>
</svg>
SVGEOF
ok "Wallpaper generated."

# ── Accesos directos ──────────────────────────────────────────────────────────
log "Creating desktop shortcuts..."
cat > "$KIOSK_HOME/Desktop/thunar.desktop" <<'D1'
[Desktop Entry]
Version=1.0
Type=Application
Name=Archivos
Exec=thunar
Icon=system-file-manager
Terminal=false
Categories=Utility;FileManager;
D1

cat > "$KIOSK_HOME/Desktop/xfce4-terminal.desktop" <<'D2'
[Desktop Entry]
Version=1.0
Type=Application
Name=Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
Categories=Utility;TerminalEmulator;
D2

cat > "$KIOSK_HOME/Desktop/mousepad.desktop" <<'D3'
[Desktop Entry]
Version=1.0
Type=Application
Name=Editor de Texto
Exec=mousepad %F
Icon=accessories-text-editor
Terminal=false
Categories=Utility;TextEditor;
D3

cat > "$KIOSK_HOME/Desktop/devos-install.desktop" <<'D4'
[Desktop Entry]
Version=1.0
Type=Application
Name=Instalar DevOS
Exec=xfce4-terminal -e "sudo /usr/local/bin/devos-install"
Icon=system-software-install
Terminal=false
Categories=System;
D4

chmod +x "$KIOSK_HOME/Desktop/"*.desktop
chown -R 1000:1000 "$KIOSK_HOME"
ok "Desktop shortcuts created."

# ── Chromium wrapper ──────────────────────────────────────────────────────────
cat > "$ROOTFS/usr/local/bin/chromium-browser" <<'WRAPPER'
#!/bin/bash
exec /usr/bin/chromium \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --memory-model=low \
    --no-first-run \
    --no-default-browser-check \
    "$@"
WRAPPER
chmod +x "$ROOTFS/usr/local/bin/chromium-browser"

# ── TTY1 autologin ────────────────────────────────────────────────────────────
mkdir -p "$ROOTFS/etc/systemd/system/getty@tty1.service.d"
cat > "$ROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<'AUTOLOGIN'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin kiosk --noclear %I $TERM
AUTOLOGIN

# ── Optimización RAM ──────────────────────────────────────────────────────────
cat > "$ROOTFS/etc/sysctl.d/99-devos.conf" <<'SYSCTL'
vm.swappiness=10
vm.vfs_cache_pressure=50
kernel.printk=3 4 1 3
SYSCTL

mkdir -p "$ROOTFS/etc/systemd/journald.conf.d"
cat > "$ROOTFS/etc/systemd/journald.conf.d/devos.conf" <<'JNL'
[Journal]
SystemMaxUse=50M
RuntimeMaxUse=20M
JNL
ok "Optimizations applied."

# ── LightDM config ────────────────────────────────────────────────────────────
cat > "$ROOTFS/etc/lightdm/lightdm.conf" <<'LDM'
[Seat:*]
autologin-user=kiosk
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
LDM

# ── Final verification ────────────────────────────────────────────────────────
echo ""
log "Final verification:"
KERNEL_VER=$(ls "$ROOTFS/lib/modules/" 2>/dev/null | grep -v rescue | sort -V | tail -1)
[[ -f "$ROOTFS/etc/os-release" ]] && ok "  os-release OK" || warn "  os-release falta"
[[ -n "$KERNEL_VER" && -f "$ROOTFS/boot/vmlinuz-${KERNEL_VER}" ]] && \
    ok "  vmlinuz OK ($KERNEL_VER)" || warn "  vmlinuz NOT in /boot"
grep -q "^kiosk:" "$ROOTFS/etc/passwd" && ok "  kiosk user OK" || warn "  kiosk not in passwd"
[[ -L "$ROOTFS/etc/systemd/system/default.target" ]] && ok "  graphical.target OK"
[[ -f "$ROOTFS/etc/systemd/system/plymouth-quit-wait.service" ]] && ok "  plymouth disabled OK"
[[ -f "$KIOSK_HOME/.xinitrc" ]] && ok "  .xinitrc OK"
[[ -f "$KIOSK_HOME/.bash_profile" ]] && ok "  .bash_profile OK"

echo ""
ok "${BOLD}Phase 01 complete.${NC}"
echo -e "  Next step: ${CYAN}sudo bash scripts/02-configure-desktop.sh${NC}"
echo ""
