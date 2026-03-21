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

**DevOS** es un sistema operativo de escritorio ligero y funcional, construido desde cero sobre Fedora 43/RPM, con XFCE como entorno de escritorio. Genera una ISO Live + Instalable, booteable por UEFI.

---

## ⚠️ Requisito de versión — IMPORTANTE

> **Este proyecto fue desarrollado y probado en Fedora 43.**
> La máquina donde construyas la ISO **debe correr Fedora 43**.
>
> Otras versiones de Fedora pueden funcionar, pero no están garantizadas.
> En particular, Fedora 41 y 42 tienen nombres de paquetes distintos que causarán errores.

Para verificar tu versión:
```bash
cat /etc/fedora-release
# Debe decir: Fedora release 43 (...)
```

---

## ¿Qué incluye?

| Componente       | Detalle                              |
|------------------|--------------------------------------|
| Base             | Fedora 43 / RPM                      |
| Kernel           | Linux 6.x (el más reciente de F43)   |
| Init             | systemd                              |
| Escritorio       | XFCE 4                               |
| Login manager    | LightDM (autologin)                  |
| Navegador        | Chromium (optimizado para VM)        |
| Archivos         | Thunar                               |
| Terminal         | XFCE Terminal                        |
| Editor           | Mousepad                             |
| Tema             | Greybird + Papirus Icons             |
| Fondo            | Wallpaper SVG personalizado DevOS    |
| Splash           | Plymouth (tema Spinner)              |
| ISO              | Live UEFI + Instalable al disco      |

---

## Requisitos

### Máquina donde SE CONSTRUYE la ISO (host)

- **Distro:** Fedora 43 (obligatorio — ver nota arriba)
- **RAM:** mínimo 4GB libres
- **Disco:** mínimo 15GB libres en `$HOME`
- **CPU:** x86_64
- **Conexión a internet** activa (descarga ~1.5GB)
- **Privilegios:** `sudo` o root

### Máquina donde SE EJECUTA DevOS (destino)

- **Tipo:** VirtualBox (instrucciones incluidas) o bare metal
- **RAM:** mínimo 1GB, recomendado 2GB
- **Disco:** mínimo 8GB si vas a instalar
- **Boot:** UEFI (obligatorio)

---

## Estructura del proyecto

```
devos/
├── README.md
└── scripts/
    ├── 00-clean.sh              ← Limpieza / reset
    ├── 01-build-rootfs.sh       ← Sistema base + XFCE
    ├── 02-configure-desktop.sh  ← Branding + escritorio
    ├── 03-build-iso.sh          ← Genera la ISO final
    └── devos-install.sh         ← Instalador al disco (dentro del Live)
```

---

## Paso a paso: Construir DevOS

### PASO 0 — Preparar

```bash
# Descomprimir el proyecto
unzip devos-build-kit.zip
cd devos

# Permisos de ejecución
chmod +x scripts/*.sh

# Verificar que estás en Fedora 43
cat /etc/fedora-release
```

---

### PASO 1 — Construir el Root Filesystem

```bash
sudo bash scripts/01-build-rootfs.sh
```

**Duración:** 20–40 minutos (descarga ~1.2GB).

**¿Qué hace?**
- Instala herramientas de build en el host
- Crea `~/devos-build/rootfs/` con Fedora 43 base
- Instala XFCE 4, Chromium, Thunar, Terminal, Mousepad
- Crea usuario `kiosk` (contraseña: `devos`)
- Copia vmlinuz desde `/usr/lib/modules/` a `/boot/` si es necesario
- Habilita LightDM, NetworkManager, udisks2

**Verificar que salió bien:**
```bash
sudo ls /root/devos-build/rootfs/boot/vmlinuz*
# Debe mostrar: vmlinuz-6.x.x-xxx.fc43.x86_64

sudo grep "kiosk" /root/devos-build/rootfs/etc/passwd
# Debe mostrar la línea del usuario kiosk

cat /root/devos-build/rootfs/etc/os-release | grep NAME
# Debe mostrar: NAME="DevOS"
```

> ⚠️ Si el script falla a mitad: ejecuta `sudo bash scripts/00-clean.sh` opción 3, luego vuelve a correr el paso 1.

---

### PASO 2 — Configurar Escritorio

```bash
sudo bash scripts/02-configure-desktop.sh
```

**Duración:** ~2 minutos.

**Verificar:**
```bash
sudo ls /root/devos-build/rootfs/home/kiosk/Desktop/
# Debe listar los .desktop de Chromium, Thunar, Terminal, etc.
```

---

### PASO 3 — Generar la ISO

```bash
sudo bash scripts/03-build-iso.sh
```

**Duración:** 20–45 minutos (la compresión XZ es lenta).

**Al terminar:**
```
╔══════════════════════════════════════════════════╗
║          ISO GENERADA EXITOSAMENTE               ║
║  Archivo : devos-desktop.iso                     ║
║  Tamaño  : ~1.5GB                                ║
║  Ruta    : /root/devos-build/output/...          ║
╚══════════════════════════════════════════════════╝
```

**Copiar la ISO a tu carpeta:**
```bash
cp /root/devos-build/output/devos-desktop.iso ~/Documentos/devos/
```

---

## Configurar VirtualBox

1. **Nueva VM** → Linux / Fedora (64-bit)
2. **RAM:** 2048 MB
3. **Disco:** VDI de 10GB (si vas a instalar; opcional para Live)
4. **Sistema → Placa base:** ✅ Habilitar EFI ← **OBLIGATORIO**
5. **Pantalla:** VMSVGA, 64MB VRAM, ❌ sin aceleración 3D
6. **Almacenamiento:** agregar `devos-desktop.iso` como óptico
7. **Red:** NAT
8. **Iniciar**

---

## Usuarios del sistema

| Usuario | Contraseña | Descripción                   |
|---------|------------|-------------------------------|
| `kiosk` | `devos`    | Usuario principal (autologin) |
| `root`  | `devos123` | Root (acceso por terminal)    |

---

## Instalar al disco (dentro de VirtualBox)

1. En el menú GRUB → **"Instalar al disco duro"**
2. O desde el escritorio → doble clic en **"Instalar DevOS"**
3. O desde terminal: `sudo devos-install`
4. El disco en VirtualBox suele ser `sda` o `vda`
5. Escribe `si` para confirmar — tarda ~5 minutos
6. Al terminar, apaga la VM, retira la ISO, reinicia

---

## Solución de problemas conocidos

### La ISO no arranca en VirtualBox
→ Ve a **Configuración → Sistema → Placa base** → marca **"Habilitar EFI"**

### Pantalla negra tras el splash
→ **Pantalla** → cambia controlador a **VMSVGA** → desactiva aceleración 3D

### Chromium no abre
```bash
chromium-browser --no-sandbox --disable-gpu
```
El wrapper en `/usr/local/bin/chromium-browser` ya incluye estos flags.

### "vmlinuz no encontrado" al generar ISO
```bash
sudo find /root/devos-build/rootfs -name "vmlinuz" 2>/dev/null
# Si está en /usr/lib/modules/:
KVER=$(ls /root/devos-build/rootfs/lib/modules/ | grep -v rescue | tail -1)
sudo cp /root/devos-build/rootfs/usr/lib/modules/$KVER/vmlinuz \
        /root/devos-build/rootfs/boot/vmlinuz-$KVER
```
*(El script 01 actualizado hace esto automáticamente)*

### Rebuild rápido de ISO (sin rehacer el rootfs)
```bash
sudo bash scripts/00-clean.sh   # opción 1
sudo bash scripts/03-build-iso.sh
```

### Desmontar bind mounts colgados
```bash
sudo bash scripts/00-clean.sh   # opción 3
```

---

## Resumen de errores encontrados durante el desarrollo

Estos errores ya están corregidos en los scripts actuales:

| Error | Causa | Fix aplicado |
|-------|-------|-------------|
| `No coincide para argumento: fedora-release` | Faltaba `--use-host-config` en dnf | Agregado en `DNF_OPTS` |
| Versión Fedora hardcodeada a 41 | Variable fija | Detección automática con `rpm -E %fedora` |
| `chpasswd: no se pudo abrir /etc/passwd` | `/proc` no montado en chroot | Montaje con `-t proc` + fallback con `sed` |
| `vmlinuz-6.x: No existe el fichero` | En Fedora 43 va a `/usr/lib/modules/` | Se copia a `/boot/` automáticamente |
| `el grupo «plugdev» no existe` | plugdev no existe en Fedora | Eliminado del `usermod` |
| `greybird-gtk2-theme: No coincide` | Paquete renombrado en F43 | Cambiado a `greybird-light-theme` |
| `polkit-gnome: No coincide` | No existe en Fedora 43 | Cambiado a `xfce-polkit` |
| `shadow permisos 000` — chpasswd falla | RPM instala shadow sin lectura | Fallback: `chmod 600` + `sed` directo |
| `systemctl enable` poco confiable en chroot | `/proc` no totalmente disponible | Reemplazado por symlinks directos |

---

## Referencia rápida

```bash
# Build completo desde cero
sudo bash scripts/01-build-rootfs.sh
sudo bash scripts/02-configure-desktop.sh
sudo bash scripts/03-build-iso.sh

# Solo rebuild de ISO
sudo bash scripts/00-clean.sh    # opción 1
sudo bash scripts/03-build-iso.sh

# Entrar al rootfs manualmente
sudo systemd-nspawn -D /root/devos-build/rootfs /bin/bash

# Tamaño del rootfs
sudo du -sh /root/devos-build/rootfs

# ISO generada
ls -lh /root/devos-build/output/devos-desktop.iso
```

---

## Grabar en USB (opcional)

```bash
# ⚠️ CUIDADO: borra todo en el USB
# Reemplaza /dev/sdX con tu dispositivo real (verifica con lsblk)
sudo dd if=/root/devos-build/output/devos-desktop.iso \
         of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

---

*DevOS — Fedora 43 / RPM · systemd · XFCE · dracut · xorriso*
