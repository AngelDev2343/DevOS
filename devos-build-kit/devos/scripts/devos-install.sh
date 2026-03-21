#!/bin/bash
# =============================================================================
# DevOS — Instalador al disco (se ejecuta DENTRO del sistema Live)
# Guardar en: /usr/local/bin/devos-install
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
echo -e "${NC}${BOLD}  Instalador DevOS 1.0${NC}"
echo "  ──────────────────────────────────────────"
echo ""

[[ $EUID -ne 0 ]] && die "Ejecuta como root: sudo devos-install"

# ── Listar discos ─────────────────────────────────────────────────────────────
echo "  Discos disponibles:"
echo "  ─────────────────────────────"
lsblk -d -o NAME,SIZE,MODEL,TYPE | grep disk | \
    awk '{printf "  /dev/%-8s  %s  %s\n", $1, $2, $3}'
echo ""

read -p "  Disco destino (ej: sda, vda, nvme0n1): " DISK
TARGET="/dev/${DISK}"

[[ ! -b "$TARGET" ]] && die "Disco no encontrado: $TARGET"

# ── Verificar que no sea el disco Live ───────────────────────────────────────
LIVE_DEV=$(lsblk -no pkname /dev/disk/by-label/DEVOS 2>/dev/null || true)
if [[ -n "$LIVE_DEV" && "/dev/$LIVE_DEV" == "$TARGET" ]]; then
    die "No puedes instalar sobre el disco Live. Elige otro disco."
fi

echo ""
echo -e "  ${RED}${BOLD}⚠️  ADVERTENCIA${NC}"
echo "  Se borrará TODO el contenido de: $TARGET"
echo "  Tamaño del disco:"
lsblk -d -o SIZE "$TARGET" | tail -1 | awk '{print "  " $0}'
echo ""
read -p "  ¿Confirmar instalación? (escribe exactamente 'si'): " CONFIRM
[[ "$CONFIRM" != "si" ]] && { echo "  Instalación cancelada."; exit 0; }

echo ""
log "Iniciando instalación en $TARGET..."

# ── Particionado ──────────────────────────────────────────────────────────────
log "[1/7] Particionando disco..."
parted "$TARGET" --script \
    mklabel gpt \
    mkpart ESP fat32 1MiB 513MiB \
    set 1 esp on \
    mkpart primary ext4 513MiB 100%

sleep 2
partprobe "$TARGET"
sleep 2

# Detectar nombres de partición
if [[ "$TARGET" == *nvme* ]]; then
    PART1="${TARGET}p1"
    PART2="${TARGET}p2"
else
    PART1="${TARGET}1"
    PART2="${TARGET}2"
fi

[[ ! -b "$PART1" ]] && die "Partición EFI no encontrada: $PART1"
[[ ! -b "$PART2" ]] && die "Partición root no encontrada: $PART2"

ok "Disco particionado."

# ── Formateo ──────────────────────────────────────────────────────────────────
log "[2/7] Formateando particiones..."
mkfs.fat -F32 -n EFI "$PART1"
mkfs.ext4 -L devos-root -F "$PART2"
ok "Particiones formateadas."

# ── Montaje ───────────────────────────────────────────────────────────────────
log "[3/7] Montando particiones..."
mount "$PART2" /mnt
mkdir -p /mnt/boot/efi
mount "$PART1" /mnt/boot/efi
ok "Particiones montadas."

# ── Copia del sistema ─────────────────────────────────────────────────────────
log "[4/7] Copiando sistema (puede tardar varios minutos)..."
rsync -aAXH \
    --info=progress2 \
    --exclude={/proc/*,/sys/*,/dev/*,/run/*,/tmp/*,/mnt/*,/media/*} \
    / /mnt/
ok "Sistema copiado."

# ── fstab ─────────────────────────────────────────────────────────────────────
log "[5/7] Configurando fstab..."
ROOT_UUID=$(blkid -s UUID -o value "$PART2")
EFI_UUID=$(blkid -s UUID -o value "$PART1")

cat > /mnt/etc/fstab <<FSTAB
UUID=$ROOT_UUID  /          ext4  defaults,noatime  0 1
UUID=$EFI_UUID   /boot/efi  vfat  umask=0077        0 2
FSTAB
ok "fstab configurado."

# ── GRUB ──────────────────────────────────────────────────────────────────────
log "[6/7] Instalando GRUB..."
for d in dev proc sys run; do mount --bind /$d /mnt/$d; done

chroot /mnt grub2-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=DevOS \
    --recheck

# grub.cfg para instalación en disco (sin parámetros Live)
cat > /mnt/etc/default/grub <<'GRUB'
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="DevOS"
GRUB_DEFAULT=0
GRUB_CMDLINE_LINUX="quiet splash"
GRUB_DISABLE_RECOVERY=true
GRUB

chroot /mnt grub2-mkconfig -o /boot/grub2/grub.cfg

for d in dev proc sys run; do umount /mnt/$d 2>/dev/null || true; done
ok "GRUB instalado."

# ── Limpieza ──────────────────────────────────────────────────────────────────
log "[7/7] Finalizando..."
umount /mnt/boot/efi
umount /mnt
ok "Instalación completada."

echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   DevOS instalado correctamente en:      ║"
echo "  ║   $TARGET                                 "
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Retira el medio de instalación y reinicia."
echo ""
read -p "  ¿Reiniciar ahora? (s/n): " REBOOT
[[ "$REBOOT" == "s" || "$REBOOT" == "S" ]] && reboot
