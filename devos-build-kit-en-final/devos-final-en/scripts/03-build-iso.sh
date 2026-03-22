#!/bin/bash
# =============================================================================
# DevOS — Script 03: ISO Booteable Live + Instalable / UEFI
# Tested on Fedora 43
#
# BUGS FIXED:
# 1. vmlinuz buscado en /boot — fallback a /usr/lib/modules/
# 2. rd.live.overlay.overlayfs causaba cuelgue en dracut → eliminado
# 3. rd.live.overlay=tmpfs causaba fallo con /dev/shm → eliminado
# 4. plymouth en initramfs causaba bloqueo → omitido en dracut
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
export ISO_STAGE="$DEVOS_BUILD/iso-stage"
export ISO_OUT="$DEVOS_BUILD/output/devos-desktop.iso"

[[ $EUID -ne 0 ]] && die "Run as root."
[[ ! -d "$ROOTFS/usr" ]] && die "Rootfs not found. Run scripts 01 and 02 first."

for cmd in mksquashfs xorriso grub2-mkimage dracut; do
    command -v "$cmd" &>/dev/null || die "Missing: $cmd — run script 01 first."
done

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   DevOS Build — Fase 03: Generar ISO      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

rm -rf "$ISO_STAGE"
mkdir -p "$ISO_STAGE"/{EFI/BOOT,boot/grub,LiveOS}
mkdir -p "$DEVOS_BUILD/output"

# ── Instalador al disco ───────────────────────────────────────────────────────
log "Copiando instalador al rootfs..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/devos-install.sh" "$ROOTFS/usr/local/bin/devos-install"
chmod +x "$ROOTFS/usr/local/bin/devos-install"

cat > "$ROOTFS/etc/systemd/system/devos-installer.service" <<'SVC'
[Unit]
Description=DevOS Disk Installer
ConditionKernelCommandLine=DEVOS_INSTALL=1
After=multi-user.target
Conflicts=lightdm.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/devos-install
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty2
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVC

mkdir -p "$ROOTFS/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/devos-installer.service \
    "$ROOTFS/etc/systemd/system/multi-user.target.wants/devos-installer.service" 2>/dev/null || true
ok "Instalador listo."

# ── Kernel ────────────────────────────────────────────────────────────────────
KERNEL_VER=$(ls "$ROOTFS/lib/modules/" | grep -v rescue | sort -V | tail -1)
[[ -z "$KERNEL_VER" ]] && die "No se encontró kernel en el rootfs."
log "Kernel: $KERNEL_VER"

# FIX #1: En Fedora 43 vmlinuz puede estar en /usr/lib/modules/
VMLINUZ="$ROOTFS/boot/vmlinuz-${KERNEL_VER}"
if [[ ! -f "$VMLINUZ" ]]; then
    VMLINUZ_ALT="$ROOTFS/usr/lib/modules/${KERNEL_VER}/vmlinuz"
    [[ -f "$VMLINUZ_ALT" ]] && cp "$VMLINUZ_ALT" "$VMLINUZ" && \
        ok "vmlinuz copied from /usr/lib/modules/ (Fedora 43 fix)" || \
        die "vmlinuz not found. Reinstall kernel-core."
fi

# ── Initramfs Live (SIN plymouth) ────────────────────────────────────────────
log "Generating Live initramfs with dracut (2-5 min)..."
# FIX #4: omit plymouth from initramfs
mount -t proc proc "$ROOTFS/proc" 2>/dev/null || true
mount -t sysfs sysfs "$ROOTFS/sys" 2>/dev/null || true
mount --bind /dev "$ROOTFS/dev" 2>/dev/null || true
mount --bind /run "$ROOTFS/run" 2>/dev/null || true

chroot "$ROOTFS" dracut \
    --force \
    --add "dmsquash-live" \
    --omit "plymouth" \
    --add-drivers "squashfs overlay dm-snapshot" \
    --omit "multipath iscsi fcoe" \
    --no-hostonly \
    --kver "$KERNEL_VER" \
    /boot/initrd-live.img || die "dracut failed."

umount "$ROOTFS/proc" 2>/dev/null || true
umount "$ROOTFS/sys"  2>/dev/null || true
umount "$ROOTFS/dev"  2>/dev/null || true
umount "$ROOTFS/run"  2>/dev/null || true
ok "Initramfs generado."

# ── Copiar kernel e initramfs ─────────────────────────────────────────────────
log "Copying kernel and initramfs to stage..."
cp "$VMLINUZ" "$ISO_STAGE/boot/vmlinuz"
cp "$ROOTFS/boot/initrd-live.img" "$ISO_STAGE/boot/initrd.img"
ok "Kernel: $(ls -lh $ISO_STAGE/boot/vmlinuz | awk '{print $5}')"
ok "Initrd: $(ls -lh $ISO_STAGE/boot/initrd.img | awk '{print $5}')"

# ── SquashFS ──────────────────────────────────────────────────────────────────
log "Creating SquashFS (15-30 min — XZ compression)..."
mksquashfs \
    "$ROOTFS" \
    "$ISO_STAGE/LiveOS/squashfs.img" \
    -comp xz -Xbcj x86 -b 1M -no-progress \
    -e "$ROOTFS/proc" -e "$ROOTFS/sys" -e "$ROOTFS/dev" \
    -e "$ROOTFS/run" -e "$ROOTFS/tmp" -e "$ROOTFS/boot/efi" \
    -e "$ROOTFS/var/cache/dnf" \
    || die "mksquashfs failed."
ok "SquashFS: $(ls -lh $ISO_STAGE/LiveOS/squashfs.img | awk '{print $5}')"

# ── EFI bootloader ────────────────────────────────────────────────────────────
log "Creating EFI image..."
dd if=/dev/zero of="$ISO_STAGE/EFI/efiboot.img" bs=1M count=10 status=none
mkfs.fat -F12 "$ISO_STAGE/EFI/efiboot.img"

EFITMP=$(mktemp -d)
mount "$ISO_STAGE/EFI/efiboot.img" "$EFITMP"
mkdir -p "$EFITMP/EFI/BOOT"
grub2-mkimage -O x86_64-efi -o "$EFITMP/EFI/BOOT/BOOTX64.EFI" -p /EFI/BOOT \
    part_gpt part_msdos fat ext2 normal boot linux echo configfile \
    search search_fs_uuid search_fs_file gzio xzio squash4 ls cat \
    all_video video_bochs video_cirrus loopback iso9660 minicmd reboot halt \
    || { umount "$EFITMP"; rm -rf "$EFITMP"; die "grub2-mkimage failed."; }
umount "$EFITMP"; rm -rf "$EFITMP"

grub2-mkimage -O x86_64-efi -o "$ISO_STAGE/EFI/BOOT/BOOTX64.EFI" -p /EFI/BOOT \
    part_gpt part_msdos fat ext2 normal boot linux echo configfile \
    search search_fs_uuid search_fs_file gzio xzio squash4 ls cat \
    all_video video_bochs video_cirrus loopback iso9660 minicmd reboot halt
ok "EFI creado."

# FIX #2 y #3: without rd.live.overlay.overlayfs or rd.live.overlay=tmpfs
# FIX nomodeset: required for VirtualBox with vmwgfx
log "Generating grub.cfg..."
cat > "$ISO_STAGE/EFI/BOOT/grub.cfg" <<'GRUBCFG'
set default=0
set timeout=8

insmod all_video
insmod gfxterm
set gfxmode=1024x768,auto
set gfxpayload=keep
terminal_output gfxterm
set color_normal=cyan/black
set color_highlight=white/blue

echo ""
echo "  DevOS 1.0 — Fedora-based Desktop"
echo "  Select an option:"
echo ""

menuentry "  DevOS 1.0 — Boot Live (no install)" --class devos --class gnu-linux {
    search --no-floppy --set=root --file /LiveOS/squashfs.img
    linux  /boot/vmlinuz root=live:CDLABEL=DEVOS rd.live.image \
           nomodeset quiet
    initrd /boot/initrd.img
}

menuentry "  DevOS 1.0 — Install to hard drive" --class devos --class gnu-linux {
    search --no-floppy --set=root --file /LiveOS/squashfs.img
    linux  /boot/vmlinuz root=live:CDLABEL=DEVOS rd.live.image \
           nomodeset quiet DEVOS_INSTALL=1
    initrd /boot/initrd.img
}

menuentry "  Apagar" { halt }
menuentry "  Reiniciar" { reboot }
GRUBCFG

cp "$ISO_STAGE/EFI/BOOT/grub.cfg" "$ISO_STAGE/boot/grub/grub.cfg"
ok "grub.cfg generado."

# ── ISO final ─────────────────────────────────────────────────────────────────
log "Building ISO with xorriso..."
xorriso -as mkisofs \
    -iso-level 3 -full-iso9660-filenames \
    -volid "DEVOS" -appid "DevOS 1.0 Desktop Live" \
    -publisher "DevOS Project" -preparer "devos-build" \
    -eltorito-alt-boot -e EFI/efiboot.img -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "$ISO_OUT" "$ISO_STAGE" \
    || die "xorriso failed."

ISO_SIZE=$(ls -lh "$ISO_OUT" | awk '{print $5}')
echo ""
echo -e "${GREEN}${BOLD}"
echo "╔══════════════════════════════════════════════════╗"
echo "║          ISO SUCCESSFULLY GENERATED               ║"
echo "╠══════════════════════════════════════════════════╣"
printf "║  File : %-38s║\n" "$(basename $ISO_OUT)"
printf "║  Size  : %-38s║\n" "$ISO_SIZE"
printf "║  Path    : %-38s║\n" "$ISO_OUT"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Load the ISO in VirtualBox with EFI enabled."
echo "  Graphics controller: VBoxSVGA (not VMSVGA)"
echo ""
