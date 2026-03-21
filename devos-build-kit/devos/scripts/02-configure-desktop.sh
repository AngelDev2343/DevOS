#!/bin/bash
# =============================================================================
# DevOS — Script 02: Configuración del Escritorio XFCE + Branding
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

# ── LightDM ───────────────────────────────────────────────────────────────────
log "Configurando LightDM..."

cat > "$ROOTFS/etc/lightdm/lightdm.conf" <<'EOF'
[Seat:*]
autologin-user=kiosk
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
EOF

cat > "$ROOTFS/etc/lightdm/lightdm-gtk-greeter.conf" <<'EOF'
[greeter]
background=#1a1a2e
theme-name=Greybird
icon-theme-name=Papirus
font-name=Noto Sans 11
indicators=~host;~spacer;~clock;~spacer;~power
clock-format=%A %d %B  %H:%M
position=50%,center 50%,center
panel-position=bottom
EOF

ok "LightDM configurado (autologin: kiosk)."

# ── Auto-login TTY fallback ───────────────────────────────────────────────────
log "Configurando auto-login en TTY1..."
mkdir -p "$ROOTFS/etc/systemd/system/getty@tty1.service.d"
cat > "$ROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin kiosk --noclear %I $TERM
EOF
ok "TTY1 autologin configurado."

# ── Directorios de perfil XFCE ────────────────────────────────────────────────
log "Creando perfil XFCE para usuario kiosk..."
mkdir -p "$XFCE_CFG/xfconf/xfce-perchannel-xml"
mkdir -p "$KIOSK_HOME/.config/autostart"
mkdir -p "$KIOSK_HOME/Desktop"

# ── Tema y apariencia ─────────────────────────────────────────────────────────
cat > "$XFCE_CFG/xfconf/xfce-perchannel-xml/xsettings.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName"     type="string" value="Greybird"/>
    <property name="IconThemeName" type="string" value="Papirus"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName"            type="string" value="Noto Sans 10"/>
    <property name="MonospaceFontName"   type="string" value="Noto Mono 10"/>
    <property name="CursorThemeName"     type="string" value="Adwaita"/>
    <property name="CursorThemeSize"     type="int"    value="24"/>
  </property>
</channel>
EOF

# ── Fondo de pantalla SVG con branding DevOS ──────────────────────────────────
log "Generando fondo de pantalla DevOS..."
mkdir -p "$ROOTFS/usr/share/backgrounds/devos"

cat > "$ROOTFS/usr/share/backgrounds/devos/wallpaper.svg" <<'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%"   stop-color="#0d0d1a"/>
      <stop offset="45%"  stop-color="#1a1a3e"/>
      <stop offset="100%" stop-color="#0a0a1f"/>
    </linearGradient>
    <linearGradient id="glow" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%"  stop-color="#4466ff" stop-opacity="0.6"/>
      <stop offset="100%" stop-color="#4466ff" stop-opacity="0"/>
    </linearGradient>
    <filter id="blur">
      <feGaussianBlur stdDeviation="40"/>
    </filter>
  </defs>

  <!-- Fondo base -->
  <rect width="1920" height="1080" fill="url(#bg)"/>

  <!-- Resplandor central difuso -->
  <ellipse cx="960" cy="540" rx="500" ry="300"
           fill="#3344cc" opacity="0.12" filter="url(#blur)"/>

  <!-- Grid horizontal -->
  <g stroke="#3355aa" stroke-opacity="0.07" stroke-width="1">
    <line x1="0" y1="135" x2="1920" y2="135"/>
    <line x1="0" y1="270" x2="1920" y2="270"/>
    <line x1="0" y1="405" x2="1920" y2="405"/>
    <line x1="0" y1="540" x2="1920" y2="540"/>
    <line x1="0" y1="675" x2="1920" y2="675"/>
    <line x1="0" y1="810" x2="1920" y2="810"/>
    <line x1="0" y1="945" x2="1920" y2="945"/>
  </g>
  <!-- Grid vertical -->
  <g stroke="#3355aa" stroke-opacity="0.07" stroke-width="1">
    <line x1="192"  y1="0" x2="192"  y2="1080"/>
    <line x1="384"  y1="0" x2="384"  y2="1080"/>
    <line x1="576"  y1="0" x2="576"  y2="1080"/>
    <line x1="768"  y1="0" x2="768"  y2="1080"/>
    <line x1="960"  y1="0" x2="960"  y2="1080"/>
    <line x1="1152" y1="0" x2="1152" y2="1080"/>
    <line x1="1344" y1="0" x2="1344" y2="1080"/>
    <line x1="1536" y1="0" x2="1536" y2="1080"/>
    <line x1="1728" y1="0" x2="1728" y2="1080"/>
  </g>

  <!-- Línea de acento horizontal superior -->
  <rect x="0" y="0" width="1920" height="2" fill="#4466ff" opacity="0.4"/>

  <!-- Círculos decorativos esquinas -->
  <circle cx="100"  cy="100"  r="60" fill="none" stroke="#4466ff" stroke-width="1" opacity="0.15"/>
  <circle cx="100"  cy="100"  r="40" fill="none" stroke="#4466ff" stroke-width="1" opacity="0.10"/>
  <circle cx="1820" cy="980" r="80" fill="none" stroke="#4466ff" stroke-width="1" opacity="0.12"/>
  <circle cx="1820" cy="980" r="50" fill="none" stroke="#4466ff" stroke-width="1" opacity="0.08"/>

  <!-- Texto principal DevOS -->
  <text x="960" y="490"
        font-family="monospace, 'Courier New', Courier"
        font-size="110"
        font-weight="bold"
        fill="#ffffff"
        fill-opacity="0.92"
        text-anchor="middle"
        letter-spacing="8">DevOS</text>

  <!-- Subtítulo -->
  <text x="960" y="548"
        font-family="monospace, 'Courier New', Courier"
        font-size="20"
        fill="#7799dd"
        fill-opacity="0.75"
        text-anchor="middle"
        letter-spacing="4">MINIMAL DESKTOP  ·  FEDORA-BASED  ·  v1.0</text>

  <!-- Línea decorativa bajo subtítulo -->
  <line x1="680" y1="572" x2="1240" y2="572"
        stroke="#4466ff" stroke-width="1" opacity="0.35"/>

  <!-- Puntos decorativos en la línea -->
  <circle cx="680"  cy="572" r="3" fill="#4466ff" opacity="0.5"/>
  <circle cx="960"  cy="572" r="3" fill="#4466ff" opacity="0.5"/>
  <circle cx="1240" cy="572" r="3" fill="#4466ff" opacity="0.5"/>

  <!-- Versión bottom-right -->
  <text x="1880" y="1060"
        font-family="monospace"
        font-size="13"
        fill="#4466ff"
        fill-opacity="0.4"
        text-anchor="end">DevOS 1.0</text>
</svg>
SVGEOF

ok "Fondo de pantalla generado."

# ── Configuración del escritorio XFCE ─────────────────────────────────────────
log "Configurando escritorio XFCE..."

cat > "$XFCE_CFG/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVirtual-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image"  type="string"
            value="/usr/share/backgrounds/devos/wallpaper.svg"/>
        </property>
      </property>
      <property name="monitorscreen" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image"  type="string"
            value="/usr/share/backgrounds/devos/wallpaper.svg"/>
        </property>
      </property>
    </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="style"  type="int"  value="2"/>
    <property name="file-icons" type="empty">
      <property name="show-home"       type="bool" value="true"/>
      <property name="show-filesystem" type="bool" value="false"/>
      <property name="show-removable"  type="bool" value="true"/>
      <property name="show-trash"      type="bool" value="true"/>
    </property>
  </property>
</channel>
EOF

# ── Panel XFCE ─────────────────────────────────────────────────────────────────
cat > "$XFCE_CFG/xfconf/xfce-perchannel-xml/xfce4-panel.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
  </property>
  <property name="panel-1" type="empty">
    <property name="position"        type="string" value="p=8;x=0;y=0"/>
    <property name="length"          type="uint"   value="100"/>
    <property name="position-locked" type="bool"   value="true"/>
    <property name="size"            type="uint"   value="30"/>
    <property name="background-style" type="int"   value="1"/>
    <property name="background-color" type="string" value="#0d0d1a"/>
    <property name="plugin-ids" type="array">
      <value type="int" value="1"/>
      <value type="int" value="2"/>
      <value type="int" value="3"/>
      <value type="int" value="4"/>
      <value type="int" value="5"/>
      <value type="int" value="6"/>
      <value type="int" value="7"/>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu">
      <property name="button-title" type="string" value="DevOS"/>
      <property name="show-button-title" type="bool" value="true"/>
    </property>
    <property name="plugin-2" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-3" type="string" value="tasklist">
      <property name="show-labels"   type="bool" value="true"/>
      <property name="flat-buttons"  type="bool" value="true"/>
    </property>
    <property name="plugin-4" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style"  type="uint" value="0"/>
    </property>
    <property name="plugin-5" type="string" value="systray"/>
    <property name="plugin-6" type="string" value="clock">
      <property name="digital-format" type="string" value="%H:%M  %a %d %b"/>
    </property>
    <property name="plugin-7" type="string" value="actions">
      <property name="appearance" type="int" value="0"/>
    </property>
  </property>
</channel>
EOF

ok "Panel XFCE configurado."

# ── Chromium wrapper (optimizado para VM) ─────────────────────────────────────
log "Configurando Chromium para VM..."

cat > "$ROOTFS/usr/local/bin/chromium-browser" <<'WRAPPER'
#!/bin/bash
# Chromium optimizado para VirtualBox/QEMU (2GB RAM, sin GPU)
exec /usr/bin/chromium \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --memory-model=low \
    --disable-background-networking \
    --no-first-run \
    --no-default-browser-check \
    "$@"
WRAPPER
chmod +x "$ROOTFS/usr/local/bin/chromium-browser"

ok "Chromium configurado."

# ── Accesos directos en el escritorio ─────────────────────────────────────────
log "Creando accesos directos..."

cat > "$KIOSK_HOME/Desktop/chromium.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Chromium
Comment=Navegador Web
Exec=chromium-browser %U
Icon=chromium
Terminal=false
Categories=Network;WebBrowser;
EOF

cat > "$KIOSK_HOME/Desktop/thunar.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Archivos
Comment=Gestor de Archivos
Exec=thunar
Icon=system-file-manager
Terminal=false
Categories=Utility;FileManager;
EOF

cat > "$KIOSK_HOME/Desktop/xfce4-terminal.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Terminal
Comment=Emulador de Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
Categories=Utility;TerminalEmulator;
EOF

cat > "$KIOSK_HOME/Desktop/mousepad.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Editor de Texto
Comment=Editor de texto simple
Exec=mousepad %F
Icon=accessories-text-editor
Terminal=false
Categories=Utility;TextEditor;
EOF

cat > "$KIOSK_HOME/Desktop/devos-install.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Instalar DevOS
Comment=Instala DevOS en el disco duro
Exec=xfce4-terminal -e "sudo /usr/local/bin/devos-install"
Icon=system-software-install
Terminal=false
Categories=System;
EOF

# Hacer ejecutables los .desktop
chmod +x "$KIOSK_HOME/Desktop/"*.desktop
ok "Accesos directos creados."

# ── Permisos finales ───────────────────────────────────────────────────────────
log "Aplicando permisos..."
chown -R 1000:1000 "$KIOSK_HOME"   # UID 1000 = kiosk
ok "Permisos aplicados."

echo ""
ok "${BOLD}Fase 02 completada. Escritorio XFCE configurado.${NC}"
echo ""
echo -e "  Siguiente paso: ${CYAN}sudo bash scripts/03-build-iso.sh${NC}"
echo ""
