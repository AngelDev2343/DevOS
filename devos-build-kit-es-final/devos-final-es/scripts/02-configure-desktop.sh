#!/bin/bash
# =============================================================================
# DevOS — Script 02: Configuración del Escritorio XFCE + Branding
# Probado en Fedora 43
#
# NOTA: La configuración principal de XFCE (wallpaper, .xinitrc, .bash_profile,
# permisos, servicios) ya se hace en el script 01. Este script solo agrega
# configuraciones adicionales de apariencia y accesos directos que no dependen
# del rootfs base.
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
KIOSK_HOME="$ROOTFS/home/kiosk"
XFCE_CFG="$KIOSK_HOME/.config/xfce4"

[[ $EUID -ne 0 ]] && die "Ejecuta como root."
[[ ! -d "$ROOTFS/usr" ]] && die "Rootfs no encontrado. Ejecuta primero 01-build-rootfs.sh"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   DevOS Build — Fase 02: Desktop XFCE    ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Verificar que el script 01 creó todo ─────────────────────────────────────
[[ ! -f "$KIOSK_HOME/.xinitrc" ]] && die ".xinitrc no encontrado. Ejecuta primero 01-build-rootfs.sh"
[[ ! -f "$KIOSK_HOME/.bash_profile" ]] && die ".bash_profile no encontrado. Ejecuta primero 01-build-rootfs.sh"

# ── xsettings: tema e íconos ──────────────────────────────────────────────────
log "Configurando tema XFCE..."
mkdir -p "$XFCE_CFG/xfconf/xfce-perchannel-xml"

cat > "$XFCE_CFG/xfconf/xfce-perchannel-xml/xsettings.xml" <<'XSET'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName"     type="string" value="Greybird"/>
    <property name="IconThemeName" type="string" value="Papirus"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName"          type="string" value="Noto Sans 10"/>
    <property name="MonospaceFontName" type="string" value="Noto Mono 10"/>
    <property name="CursorThemeName"   type="string" value="Adwaita"/>
    <property name="CursorThemeSize"   type="int"    value="24"/>
  </property>
</channel>
XSET
ok "Tema configurado: Greybird + Papirus."

# ── Panel XFCE ────────────────────────────────────────────────────────────────
log "Configurando panel XFCE..."
cat > "$XFCE_CFG/xfconf/xfce-perchannel-xml/xfce4-panel.xml" <<'PANEL'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
  </property>
  <property name="panel-1" type="empty">
    <property name="position"         type="string" value="p=8;x=0;y=0"/>
    <property name="length"           type="uint"   value="100"/>
    <property name="position-locked"  type="bool"   value="true"/>
    <property name="size"             type="uint"   value="30"/>
    <property name="background-style" type="int"    value="1"/>
    <property name="background-color" type="string" value="#0d0d1a"/>
    <property name="plugin-ids" type="array">
      <value type="int" value="1"/>
      <value type="int" value="2"/>
      <value type="int" value="3"/>
      <value type="int" value="4"/>
      <value type="int" value="5"/>
      <value type="int" value="6"/>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu">
      <property name="button-title"       type="string" value="DevOS"/>
      <property name="show-button-title"  type="bool"   value="true"/>
    </property>
    <property name="plugin-2" type="string" value="tasklist">
      <property name="show-labels"  type="bool" value="true"/>
      <property name="flat-buttons" type="bool" value="true"/>
    </property>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style"  type="uint" value="0"/>
    </property>
    <property name="plugin-4" type="string" value="systray"/>
    <property name="plugin-5" type="string" value="clock">
      <property name="digital-format" type="string" value="%H:%M  %a %d %b"/>
    </property>
    <property name="plugin-6" type="string" value="actions">
      <property name="appearance" type="int" value="0"/>
    </property>
  </property>
</channel>
PANEL
ok "Panel configurado."

# ── LightDM greeter ───────────────────────────────────────────────────────────
log "Configurando LightDM greeter..."
cat > "$ROOTFS/etc/lightdm/lightdm-gtk-greeter.conf" <<'GREETER'
[greeter]
background=#1a1a2e
theme-name=Greybird
icon-theme-name=Papirus
font-name=Noto Sans 11
indicators=~host;~spacer;~clock;~spacer;~power
clock-format=%A %d %B  %H:%M
position=50%,center 50%,center
panel-position=bottom
GREETER
ok "LightDM greeter configurado."

# ── Permisos finales ──────────────────────────────────────────────────────────
log "Aplicando permisos..."
chown -R 1000:1000 "$KIOSK_HOME"
ok "Permisos aplicados."

# ── Verificación ──────────────────────────────────────────────────────────────
echo ""
log "Verificación:"
[[ -f "$XFCE_CFG/xfconf/xfce-perchannel-xml/xsettings.xml" ]] && ok "  xsettings.xml OK"
[[ -f "$XFCE_CFG/xfconf/xfce-perchannel-xml/xfce4-panel.xml" ]] && ok "  xfce4-panel.xml OK"
[[ -f "$KIOSK_HOME/Desktop/thunar.desktop" ]] && ok "  accesos directos OK"

echo ""
ok "${BOLD}Fase 02 completada.${NC}"
echo -e "  Siguiente: ${CYAN}sudo bash scripts/03-build-iso.sh${NC}"
echo ""
