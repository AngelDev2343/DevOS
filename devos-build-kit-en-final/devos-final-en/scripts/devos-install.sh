#!/bin/bash
# =============================================================================
# DevOS — Disk Installer (runs INSIDE the Live system)
# Save to: /usr/local/bin/devos-install
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
die()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

clear
echo -e "${CYAN}${BOLD}"
cat <<'BANNER'

  ██████╗ ███████╗██╗   ██╗ ██████╗ ███████╗
  ██╔══██╗██╔════╝██║   ██║██╔═══██╗██╔════╝
  ██║  ██║█████╗  ██║   ██║██║   ██║███████╗
  ██║  ██║██╔══╝  ╚██╗ ██╔╝██║   ██║╚════██║
  ██████╔╝███████╗ ╚████╔╝ ╚██████╔╝███████║
  ╚═════╝ ╚══════╝  ╚═══╝   ╚═════╝ ╚══════╝

BANNER
echo -e "${NC}${BOLD}  DevOS 1.0 Installer${NC}"
echo "  ──────────────────────────────────────────"
echo ""

[[ $EUID -ne 0 ]] && die "Run as root: sudo devos-install"

echo "  Available disks:"
echo "  ─────────────────────────────"
lsblk -d -o NAME,SIZE,MODEL,TYPE | grep disk | \
    awk '{printf "  /dev/%-8s  %s  %s\n", $1, $2, $3}'
echo ""

read -p "  Target disk (e.g.: sda, vda, nvme0n1): " DISK
TARGET="/dev/${DISK}"
[[ ! -b "$TARGET" ]] && die "Disk not found: $TARGET"

LIVE_DEV=$(lsblk -no pkname /dev/disk/by-label/DEVOS 2>/dev/null || true)
if [[ -n "$LIVE_DEV" && "/dev/$LIVE_DEV" == "$TARGET" ]]; then
    die "Cannot install to the Live disk. Choose a different disk."
fi

echo ""
echo -e "  ${RED}${BOLD}⚠️  WARNING${NC}"
echo "  ALL data on $TARGET will be erased."
echo "  Disk size:"
lsblk -d -o SIZE "$TARGET" | tail -1 | awk '{print "  " $0}'
echo ""
read -p "  Confirm installation? (type exactly 'yes'): " CONFIRM
[[ "$CONFIRM" != "yes" ]] && { echo "  Installation cancelled."; exit 0; }

echo ""
log "Starting installation on $TARGET..."

log "[1/7] Partitioning disk..."
parted "$TARGET" --script \
    mklabel gpt \
    mkpart ESP fat32 1MiB 513MiB \
    set 1 esp on \
    mkpart primary ext4 513MiB 100%

sleep 2; partprobe "$TARGET"; sleep 2

if [[ "$TARGET" == *nvme* ]]; then
    PART1="${TARGET}p1"; PART2="${TARGET}p2"
else
    PART1="${TARGET}1"; PART2="${TARGET}2"
fi

[[ ! -b "$PART1" ]] && die "EFI partition not found: $PART1"
[[ ! -b "$PART2" ]] && die "Root partition not found: $PART2"
ok "Disk partitioned."

log "[2/7] Formatting partitions..."
mkfs.fat -F32 -n EFI "$PART1"
mkfs.ext4 -L devos-root -F "$PART2"
ok "Partitions formatted."

log "[3/7] Mounting partitions..."
mount "$PART2" /mnt
mkdir -p /mnt/boot/efi
mount "$PART1" /mnt/boot/efi
ok "Partitions mounted."

log "[4/7] Copying system (this may take a few minutes)..."
rsync -aAXH \
    --info=progress2 \
    --exclude={/proc/*,/sys/*,/dev/*,/run/*,/tmp/*,/mnt/*,/media/*} \
    / /mnt/
ok "System copied."

log "[5/7] Configuring fstab..."
ROOT_UUID=$(blkid -s UUID -o value "$PART2")
EFI_UUID=$(blkid -s UUID -o value "$PART1")
cat > /mnt/etc/fstab <<FSTAB
UUID=$ROOT_UUID  /          ext4  defaults,noatime  0 1
UUID=$EFI_UUID   /boot/efi  vfat  umask=0077        0 2
FSTAB
ok "fstab configured."

log "[6/7] Installing GRUB..."
for d in dev proc sys run; do mount --bind /$d /mnt/$d; done

chroot /mnt grub2-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=DevOS \
    --recheck

cat > /mnt/etc/default/grub <<'GRUBCONF'
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="DevOS"
GRUB_DEFAULT=0
GRUB_CMDLINE_LINUX="quiet splash"
GRUB_DISABLE_RECOVERY=true
GRUBCONF

chroot /mnt grub2-mkconfig -o /boot/grub2/grub.cfg
for d in dev proc sys run; do umount /mnt/$d 2>/dev/null || true; done
ok "GRUB installed."

log "[7/7] Finalizing..."
umount /mnt/boot/efi
umount /mnt
ok "Installation complete."

echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   DevOS successfully installed on:       ║"
echo "  ║   $TARGET"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Remove the installation media and reboot."
echo ""
read -p "  Reboot now? (y/n): " REBOOT
[[ "$REBOOT" == "y" || "$REBOOT" == "Y" ]] && reboot
