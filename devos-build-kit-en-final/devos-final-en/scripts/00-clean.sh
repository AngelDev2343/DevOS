#!/bin/bash
# =============================================================================
# DevOS — Cleanup / Reset Tool
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
die()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

export DEVOS_BUILD="${DEVOS_BUILD:-$HOME/devos-build}"
export ROOTFS="$DEVOS_BUILD/rootfs"

[[ $EUID -ne 0 ]] && die "Run as root."

echo ""
echo -e "${BOLD}DevOS — Cleanup Tool${NC}"
echo ""
echo "  1) Clean ISO stage only (fast ISO rebuild)"
echo "  2) Clean rootfs + ISO stage (full rebuild)"
echo "  3) Unmount stuck bind mounts"
echo "  4) Cancel"
echo ""
read -p "  Option: " OPT

case "$OPT" in
1)
    log "Cleaning ISO stage..."
    rm -rf "$DEVOS_BUILD/iso-stage"
    rm -f  "$DEVOS_BUILD/output/devos-desktop.iso"
    ok "ISO stage cleaned. Run: sudo bash scripts/03-build-iso.sh"
    ;;
2)
    warn "This will delete the entire rootfs (~2-4GB)."
    read -p "  Confirm? (yes/no): " CONF
    [[ "$CONF" != "yes" ]] && { echo "Cancelled."; exit 0; }
    log "Unmounting bind mounts..."
    for d in dev proc sys run; do
        umount "$ROOTFS/$d" 2>/dev/null || true
    done
    log "Removing rootfs and ISO stage..."
    rm -rf "$DEVOS_BUILD/rootfs"
    rm -rf "$DEVOS_BUILD/iso-stage"
    rm -f  "$DEVOS_BUILD/output/devos-desktop.iso"
    ok "Full cleanup done. Run scripts from 01."
    ;;
3)
    log "Unmounting stuck bind mounts..."
    for d in dev proc sys run; do
        umount "$ROOTFS/$d" 2>/dev/null && ok "Unmounted: $d" || warn "Not mounted: $d"
    done
    umount "$DEVOS_BUILD/rootfs/boot/efi" 2>/dev/null || true
    umount "$DEVOS_BUILD/rootfs"          2>/dev/null || true
    ok "Done."
    ;;
4|*)
    echo "Cancelled."
    ;;
esac
