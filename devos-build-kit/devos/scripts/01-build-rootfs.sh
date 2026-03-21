#!/bin/bash
# =============================================================================
# DevOS — Script 01: Construcción del Root Filesystem
# Probado en Fedora 43 / RPM
#
# ERRORES CORREGIDOS:
# 1. --use-host-config faltaba en dnf --installroot
# 2. Versión de Fedora hardcodeada a 41 → ahora se detecta automáticamente
# 3. chpasswd fallaba por /proc no montado → montaje directo -t proc + fallback con sed
# 4. vmlinuz no en /boot en Fedora 43 → se copia desde /usr/lib/modules/
# 5. plugdev no existe en Fedora → eliminado del usermod
# 6. greybird-gtk2/gtk3-theme renombrados → greybird-light-theme / dark-theme
# 7. polkit-gnome no existe en Fedora 43 → xfce-polkit
# 8. shadow con permisos 000 → chmod 600 temporal + sed directo como fallback
# 9. systemctl en chroot poco confiable → symlinks directos para servicios
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

[[ $EUID -ne 0 ]] && die "Ejecuta este script con sudo o como root."
command -v dnf &>/dev/null || die "dnf no encontrado. Necesitas Fedora 43."
command -v rpm &>/dev/null || die "rpm no encontrado."

# FIX #2: detectar versión real
FEDORA_RELEASE=$(rpm -E %fedora 2>/dev/null)
[[ -z "$FEDORA_RELEASE" || "$FEDORA_RELEASE" == "%fedora" ]] && \
    FEDORA_RELEASE=$(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
[[ -z "$FEDORA_RELEASE" ]] && FEDORA_RELEASE=43

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   DevOS Build — Fase 01: Root Filesystem  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
log "Fedora del host: versión $FEDORA_RELEASE"

[[ "$FEDORA_RELEASE" != "43" ]] && \
    warn "Probado en Fedora 43. Usas $FEDORA_RELEASE — puede funcionar pero sin garantía."

# ── Herramientas del host ─────────────────────────────────────────────────────
log "Instalando herramientas de build..."
for pkg in squashfs-tools grub2-tools grub2-efi-x64 grub2-efi-x64-modules \
           grub2-pc-modules xorriso dosfstools dracut dracut-live \
           dracut-squash systemd-container edk2-ovmf; do
    dnf install -y "$pkg" &>/dev/null && log "  OK: $pkg" || warn "  omitido: $pkg"
done
ok "Herramientas listas."

# ── Directorios ───────────────────────────────────────────────────────────────
mkdir -p "$DEVOS_BUILD"/{rootfs,iso-stage,output,scripts}
mkdir -p "$DEVOS_BUILD/iso-stage"/{EFI/BOOT,boot/grub,LiveOS}
ok "Directorios creados."

# FIX #1: --use-host-config es obligatorio para que dnf encuentre los repos
DNF_OPTS="--installroot=$ROOTFS --releasever=$FEDORA_RELEASE --use-host-config --setopt=install_weak_deps=False --nodocs -y"

# ── Sistema base ──────────────────────────────────────────────────────────────
log "Instalando sistema base Fedora $FEDORA_RELEASE (~800MB, 10-20 min)..."

dnf install $DNF_OPTS fedora-release \
    || die "No se pudo instalar fedora-release. Verifica conexión."

for pkg in systemd systemd-udev passwd shadow-utils util-linux coreutils bash \
           dnf glibc glibc-minimal-langpack NetworkManager iproute iputils \
           procps-ng psmisc less vim-minimal sudo openssh-server \
           kernel kernel-core linux-firmware dracut dracut-live dracut-network; do
    dnf install $DNF_OPTS "$pkg" &>/dev/null && log "  OK: $pkg" || warn "  omitido: $pkg"
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
        ok "vmlinuz copiado a /boot/ (fix Fedora 43)" || \
        warn "vmlinuz no encontrado — el script 03 puede fallar"
else
    ok "vmlinuz ya está en /boot/"
fi

# ── XFCE + apps ───────────────────────────────────────────────────────────────
log "Instalando XFCE (~400MB)..."
dnf install $DNF_OPTS @xfce-desktop || die "Falló @xfce-desktop."

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
    dnf install $DNF_OPTS "$pkg" &>/dev/null && log "  OK: $pkg" || warn "  omitido: $pkg"
done
ok "XFCE instalado."

# ── Configuración básica ──────────────────────────────────────────────────────
log "Configurando sistema..."
echo "devos" > "$ROOTFS/etc/hostname"
echo "LANG=es_MX.UTF-8" > "$ROOTFS/etc/locale.conf"
ln -sf /usr/share/zoneinfo/America/Mexico_City "$ROOTFS/etc/localtime" 2>/dev/null || true

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
log "Creando usuario kiosk..."

# FIX #3: Montar con -t proc en lugar de --bind (más confiable en chroot)
mount -t proc proc "$ROOTFS/proc" 2>/dev/null || true
mount -t sysfs sysfs "$ROOTFS/sys" 2>/dev/null || true
mount --bind /dev "$ROOTFS/dev" 2>/dev/null || true
mount --bind /run "$ROOTFS/run" 2>/dev/null || true

# Intentar chpasswd normal primero
if chroot "$ROOTFS" /bin/bash -c "echo 'root:devos123' | chpasswd" 2>/dev/null; then
    chroot "$ROOTFS" /bin/bash -c "
        useradd -m -s /bin/bash -c 'DevOS User' kiosk 2>/dev/null || true
        echo 'kiosk:devos' | chpasswd
        usermod -aG wheel,audio,video kiosk
    " && ok "Usuarios creados con chpasswd."
else
    # FIX #8: Fallback directo con sed si chpasswd falla (shadow con permisos 000)
    warn "chpasswd no disponible — usando método directo..."
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
    # FIX #5: sin plugdev — solo wheel/audio/video
    grep -q "kiosk" <<< "$(grep "^wheel:" "$ROOTFS/etc/group")" || \
        sed -i 's/^wheel:x:10:/wheel:x:10:kiosk/' "$ROOTFS/etc/group"
    grep -q "kiosk" <<< "$(grep "^audio:" "$ROOTFS/etc/group")" || \
        sed -i 's/^audio:x:63:/audio:x:63:kiosk/' "$ROOTFS/etc/group"
    grep -q "kiosk" <<< "$(grep "^video:" "$ROOTFS/etc/group")" || \
        sed -i 's/^video:x:39:/video:x:39:kiosk/' "$ROOTFS/etc/group"
    chmod 000 "$ROOTFS/etc/shadow"
    ok "Usuarios creados con método directo."
fi

umount "$ROOTFS/proc" 2>/dev/null || true
umount "$ROOTFS/sys"  2>/dev/null || true
umount "$ROOTFS/dev"  2>/dev/null || true
umount "$ROOTFS/run"  2>/dev/null || true

echo "kiosk ALL=(ALL) NOPASSWD: ALL" > "$ROOTFS/etc/sudoers.d/kiosk"
chmod 440 "$ROOTFS/etc/sudoers.d/kiosk"
ok "Usuario kiosk listo (pass: devos)."

# ── Servicios ─────────────────────────────────────────────────────────────────
log "Habilitando servicios..."
# FIX #9: symlinks directos — más confiable que systemctl en chroot
mkdir -p "$ROOTFS/etc/systemd/system/multi-user.target.wants"
mkdir -p "$ROOTFS/etc/systemd/system/graphical.target.wants"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
    "$ROOTFS/etc/systemd/system/multi-user.target.wants/NetworkManager.service" 2>/dev/null || true
ln -sf /usr/lib/systemd/system/lightdm.service \
    "$ROOTFS/etc/systemd/system/display-manager.service" 2>/dev/null || true
ln -sf /usr/lib/systemd/system/udisks2.service \
    "$ROOTFS/etc/systemd/system/graphical.target.wants/udisks2.service" 2>/dev/null || true
ok "Servicios habilitados."

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
ok "Optimizaciones aplicadas."

# ── Verificación final ────────────────────────────────────────────────────────
echo ""
log "Verificación final del rootfs:"
KERNEL_VER=$(ls "$ROOTFS/lib/modules/" 2>/dev/null | grep -v rescue | sort -V | tail -1)
[[ -f "$ROOTFS/etc/os-release" ]] && ok "  os-release OK" || warn "  os-release falta"
[[ -n "$KERNEL_VER" && -f "$ROOTFS/boot/vmlinuz-${KERNEL_VER}" ]] && \
    ok "  vmlinuz OK ($KERNEL_VER)" || warn "  vmlinuz NO está en /boot — revisar"
grep -q "^kiosk:" "$ROOTFS/etc/passwd" && ok "  usuario kiosk OK" || warn "  kiosk no en passwd"
[[ -L "$ROOTFS/etc/systemd/system/display-manager.service" ]] && \
    ok "  lightdm habilitado OK" || warn "  lightdm no habilitado"

echo ""
ok "${BOLD}Fase 01 completada.${NC}"
echo -e "  Siguiente: ${CYAN}sudo bash scripts/02-configure-desktop.sh${NC}"
echo ""
