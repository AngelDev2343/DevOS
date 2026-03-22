#!/bin/bash
# =============================================================================
# DevOS — Script de limpieza / rebuild
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
die()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

export DEVOS_BUILD="${DEVOS_BUILD:-$HOME/devos-build}"
export ROOTFS="$DEVOS_BUILD/rootfs"

[[ $EUID -ne 0 ]] && die "Ejecuta como root."

echo ""
echo -e "${BOLD}DevOS — Herramienta de limpieza${NC}"
echo ""
echo "  1) Limpiar solo ISO stage (rebuild rápido de ISO)"
echo "  2) Limpiar rootfs + ISO stage (rebuild completo)"
echo "  3) Desmontar bind mounts colgados"
echo "  4) Cancelar"
echo ""
read -p "  Opción: " OPT

case "$OPT" in
1)
    log "Limpiando ISO stage..."
    rm -rf "$DEVOS_BUILD/iso-stage"
    rm -f  "$DEVOS_BUILD/output/devos-desktop.iso"
    ok "ISO stage limpiado. Ejecuta: sudo bash scripts/03-build-iso.sh"
    ;;
2)
    warn "Esto eliminará el rootfs completo (~2-4GB)."
    read -p "  ¿Confirmar? (si/no): " CONF
    [[ "$CONF" != "si" ]] && { echo "Cancelado."; exit 0; }
    log "Desmontando bind mounts..."
    for d in dev proc sys run; do
        umount "$ROOTFS/$d" 2>/dev/null || true
    done
    log "Eliminando rootfs e ISO stage..."
    rm -rf "$DEVOS_BUILD/rootfs"
    rm -rf "$DEVOS_BUILD/iso-stage"
    rm -f  "$DEVOS_BUILD/output/devos-desktop.iso"
    ok "Limpieza completa. Ejecuta los scripts desde el 01."
    ;;
3)
    log "Desmontando bind mounts colgados..."
    for d in dev proc sys run; do
        umount "$ROOTFS/$d" 2>/dev/null && ok "Desmontado: $d" || warn "No montado: $d"
    done
    umount "$DEVOS_BUILD/rootfs/boot/efi" 2>/dev/null || true
    umount "$DEVOS_BUILD/rootfs"          2>/dev/null || true
    ok "Listo."
    ;;
4|*)
    echo "Cancelado."
    ;;
esac
