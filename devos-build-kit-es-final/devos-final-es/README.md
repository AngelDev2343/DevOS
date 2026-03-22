# DevOS — Sistema Operativo Mínimo Basado en Fedora/RPM

```
  ██████╗ ███████╗██╗   ██╗ ██████╗ ███████╗
  ██╔══██╗██╔════╝██║   ██║██╔═══██╗██╔════╝
  ██║  ██║█████╗  ██║   ██║██║   ██║███████╗
  ██║  ██║██╔══╝  ╚██╗ ██╔╝██║   ██║╚════██║
  ██████╔╝███████╗ ╚████╔╝ ╚██████╔╝███████║
  ╚═════╝ ╚══════╝  ╚═══╝   ╚═════╝ ╚══════╝

  DevOS 1.0 — Fedora-based Desktop
```

**DevOS** es un sistema operativo de escritorio ligero y funcional, construido desde cero sobre Fedora 43/RPM, con XFCE como entorno de escritorio. Genera una **ISO Live booteable por UEFI**.

---

## ⚠️ Requisito de versión — IMPORTANTE

> **Este proyecto fue desarrollado y probado en Fedora 43.**
> La máquina donde construyas la ISO **debe correr Fedora 43**.

```bash
cat /etc/fedora-release
# Debe decir: Fedora release 43 (...)
```

---

## ¿Qué incluye?

| Componente     | Detalle                            |
|----------------|------------------------------------|
| Base           | Fedora 43 / RPM                    |
| Kernel         | Linux 6.x (Fedora 43)              |
| Init           | systemd                            |
| Escritorio     | XFCE 4                             |
| Login          | Autologin via .bash_profile        |
| Navegador      | Chromium (optimizado para VM)      |
| Archivos       | Thunar                             |
| Terminal       | XFCE Terminal                      |
| Editor         | Mousepad                           |
| Tema           | Greybird + Papirus Icons           |
| Fondo          | Wallpaper SVG DevOS personalizado  |
| ISO            | Live UEFI (modo sin instalación)   |

---

## Requisitos del sistema de build

- **Distro:** Fedora 43 (obligatorio)
- **RAM:** mínimo 4GB libres
- **Disco:** mínimo 15GB libres en `$HOME`
- **CPU:** x86_64
- **Internet** activo durante el build (~1.5GB de descarga)
- **Privilegios:** sudo o root

---

## Estructura del proyecto

```
devos/
├── README.md
└── scripts/
    ├── 00-clean.sh              ← Limpieza / reset
    ├── 01-build-rootfs.sh       ← Sistema base + XFCE + toda la config
    ├── 02-configure-desktop.sh  ← Tema, panel, greeter
    ├── 03-build-iso.sh          ← Genera la ISO final
    └── devos-install.sh         ← (Reservado para futuras versiones)
```

---

## Paso a paso: Construir DevOS

### PASO 0 — Preparar

```bash
unzip devos-build-kit-es-final.zip
cd devos-final-es
chmod +x scripts/*.sh
cat /etc/fedora-release   # verificar Fedora 43
```

### PASO 1 — Construir el Root Filesystem

```bash
sudo bash scripts/01-build-rootfs.sh
```

**Duración:** 20–40 minutos (~1.2GB de descarga).

**¿Qué hace?**
- Instala herramientas de build en el host
- Crea `~/devos-build/rootfs/` con Fedora 43
- Instala XFCE 4, Chromium, Thunar, Terminal, Mousepad
- Crea usuario `kiosk` (contraseña: `devos`)
- Copia vmlinuz a `/boot/` si solo está en `/usr/lib/modules/`
- Configura autologin via `.bash_profile` + `.xinitrc`
- Deshabilita plymouth completamente
- Configura `graphical.target` como default
- Genera el wallpaper SVG de DevOS
- Configura `xfce4-desktop.xml` con los 3 monitores de VirtualBox

**Verificar:**
```bash
sudo ls /root/devos-build/rootfs/boot/vmlinuz*
sudo grep "kiosk" /root/devos-build/rootfs/etc/passwd
sudo cat /root/devos-build/rootfs/home/kiosk/.xinitrc
```

### PASO 2 — Configurar Escritorio

```bash
sudo bash scripts/02-configure-desktop.sh
```

**Duración:** ~1 minuto. Configura tema, panel y greeter de XFCE.

### PASO 3 — Generar la ISO

```bash
sudo bash scripts/03-build-iso.sh
```

**Duración:** 20–45 minutos (compresión XZ).

Al terminar:
```
╔══════════════════════════════════════════════════╗
║          ISO GENERADA EXITOSAMENTE               ║
║  Archivo : devos-desktop.iso                     ║
║  Tamaño  : ~1.5GB                                ║
╚══════════════════════════════════════════════════╝
```

Copiar a Descargas:
```bash
sudo cp /root/devos-build/output/devos-desktop.iso ~/Descargas/
sudo chown $USER:$USER ~/Descargas/devos-desktop.iso
```

---

## Configurar VirtualBox

| Ajuste | Valor |
|--------|-------|
| RAM | 2048 MB |
| Sistema → Placa base | ✅ **Habilitar EFI** (obligatorio) |
| Pantalla → Controlador | **VBoxSVGA** (no VMSVGA) |
| Video RAM | 64 MB |
| Aceleración 3D | ❌ Desactivar |
| Red | NAT |

> ⚠️ Sin EFI habilitado la ISO no arranca.
> ⚠️ Usa VBoxSVGA, no VMSVGA — VMSVGA causa errores vmwgfx.

---

## Configurar QEMU/KVM (recomendado)

```bash
# Crear disco virtual
qemu-img create -f qcow2 ~/devos-disk.qcow2 20G

# Copiar vars OVMF
cp /usr/share/edk2/ovmf/OVMF_VARS.fd ~/devos-ovmf-vars.fd

# Arrancar Live
qemu-system-x86_64 \
    -name "DevOS" -m 2048 -smp 2 -enable-kvm \
    -drive file=/usr/share/edk2/ovmf/OVMF_CODE.fd,if=pflash,format=raw,readonly=on \
    -drive file=$HOME/devos-ovmf-vars.fd,if=pflash,format=raw \
    -cdrom ~/Descargas/devos-desktop.iso \
    -boot d -vga virtio -display gtk \
    -device virtio-net-pci,netdev=net0 -netdev user,id=net0
```

> Si KVM no funciona por conflicto con VirtualBox:
> ```bash
> sudo modprobe -r vboxdrv vboxnetflt vboxnetadp
> sudo modprobe kvm_intel
> ```

---

## Usuarios del sistema

| Usuario | Contraseña | Descripción |
|---------|------------|-------------|
| `kiosk` | `devos` | Usuario principal (autologin) |
| `root` | `devos123` | Root |

---

## Solución de problemas

### La ISO no arranca en VirtualBox
→ **Configuración → Sistema → Placa base → ✅ Habilitar EFI**

### Pantalla negra / errores vmwgfx
→ Cambiar controlador gráfico a **VBoxSVGA** (no VMSVGA)

### El escritorio no carga, se queda en consola del kernel
→ Presionar **Alt+F2**, login como root, ejecutar:
```bash
systemctl start lightdm
```
Si esto lo resuelve temporalmente, significa que el squashfs no tiene los cambios más recientes — regenerar con el script 03.

### plymouth-quit-wait bloquea el arranque
→ Ya está deshabilitado en los scripts. Si persiste:
```bash
sudo ln -sf /dev/null /root/devos-build/rootfs/etc/systemd/system/plymouth-quit-wait.service
```
Luego regenerar squashfs e ISO.

### El wallpaper no carga (sale el de Fedora)
→ Dentro del sistema Live, ejecutar:
```bash
for m in monitorNone-1 monitorscreen monitorVirtual-1; do
    xfconf-query -c xfce4-desktop \
        -p /backdrop/screen0/${m}/workspace0/last-image \
        -s /usr/share/backgrounds/devos/wallpaper.svg
done
xfdesktop --reload
```

### KVM no disponible (conflicto con VirtualBox)
```bash
sudo modprobe -r vboxdrv vboxnetflt vboxnetadp
sudo modprobe kvm_intel
```

### Rebuild rápido de ISO (sin rehacer el rootfs)
```bash
sudo bash scripts/00-clean.sh   # opción 1
sudo bash scripts/03-build-iso.sh
```

---

## Todos los errores encontrados y sus fixes

| # | Error | Causa | Fix aplicado |
|---|-------|-------|-------------|
| 1 | `No coincide para argumento: fedora-release` | Faltaba `--use-host-config` en dnf | Agregado en `DNF_OPTS` |
| 2 | Versión Fedora hardcodeada a 41 | Variable estática | Auto-detección con `rpm -E %fedora` |
| 3 | `chpasswd: no se pudo abrir /etc/passwd` | `/proc` no montado en chroot | Montaje con `-t proc` + fallback `sed` directo |
| 4 | `vmlinuz-6.x: No existe el fichero` | En Fedora 43 va a `/usr/lib/modules/` | Auto-copiado a `/boot/` |
| 5 | `el grupo «plugdev» no existe` | No existe en Fedora | Eliminado del `usermod` |
| 6 | `greybird-gtk2/gtk3-theme: No coincide` | Renombrado en Fedora 43 | `greybird-light/dark-theme` |
| 7 | `polkit-gnome: No coincide` | No existe en Fedora 43 | `xfce-polkit` |
| 8 | `chpasswd` falla con shadow en 000 | RPM instala shadow sin permisos de lectura | `chmod 600` temporal + `sed` directo |
| 9 | `systemctl enable` poco confiable en chroot | `/proc` no completamente disponible | Symlinks directos de systemd |
| 10 | Sistema arranca en consola en lugar de escritorio | `graphical.target` no era el default | Symlink `default.target → graphical.target` |
| 11 | `plymouth-quit-wait` bloqueaba el arranque 20+ min | Plymouth esperaba display manager | Deshabilitado con `/dev/null` |
| 12 | XFCE no iniciaba automáticamente | Faltaban `.xinitrc` y `.bash_profile` | Agregados con `exec xfce4-session` y `exec startx` |
| 13 | Wallpaper de Fedora en lugar de DevOS | `xfce4-desktop.xml` no tenía los monitores de VirtualBox | XML actualizado con `monitorNone-1`, `monitorscreen`, `monitorVirtual-1` |
| 14 | `dracut-initqueue` colgado 20+ min | `rd.live.overlay.overlayfs` causa fallo con `/dev/shm` en VirtualBox | Eliminado del grub.cfg |
| 15 | Errores `vmwgfx` en VirtualBox | Driver vmwgfx es para VMware, no VirtualBox | `nomodeset` en grub.cfg + controlador VBoxSVGA |
| 16 | Plymouth en initramfs bloqueaba | Módulo plymouth en dracut conflictuaba | `--omit plymouth` en dracut |

---

## Referencia rápida

```bash
# Build completo
sudo bash scripts/01-build-rootfs.sh
sudo bash scripts/02-configure-desktop.sh
sudo bash scripts/03-build-iso.sh

# Solo rebuild de ISO
sudo bash scripts/00-clean.sh    # opción 1
sudo bash scripts/03-build-iso.sh

# Entrar al rootfs
sudo systemd-nspawn -D /root/devos-build/rootfs /bin/bash

# Tamaño del rootfs
sudo du -sh /root/devos-build/rootfs

# ISO generada
ls -lh /root/devos-build/output/devos-desktop.iso
```

---

*DevOS — Fedora 43 / RPM · systemd · XFCE · dracut · xorriso*
