#!/bin/bash
# =========================================================
# Script seguro para eliminar una partición y redimensionar otra
# con vista previa del mapa de discos antes de ejecutar cambios.
# Autor: Hector Mor
# Fecha: 2024-06-27
# Permisos: Debe ejecutarse con sudo o como root
# chmod +x redimensionar_particion_seguro.sh
# Uso:
#   sudo ./redimensionar_particion_seguro.sh /dev/sdX /dev/sdXY /dev/sdXZ
# Ejemplo:
#   sudo ./redimensionar_particion_seguro.sh /dev/sda /dev/sda4 /dev/sda3
# =========================================================

set -euo pipefail

# ========================
# Validación de parámetros
# ========================
if [[ $# -ne 3 ]]; then
    echo "Uso: sudo $0 <DISCO> <PARTICION_ELIMINAR> <PARTICION_REDIMENSIONAR>"
    echo "Ejemplo: sudo $0 /dev/sda /dev/sda4 /dev/sda3"
    exit 1
fi

DISK="$1"
PART_DEL="$2"
PART_RESIZE="$3"

# ========================
# Verificar permisos root
# ========================
if [[ $EUID -ne 0 ]]; then
    echo "❌ Este script debe ejecutarse como root o con sudo."
    exit 1
fi


# ========================
# Mostrar mapa de discos
# ========================
echo "🔍 Mapa actual de discos y particiones:"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
echo
echo "📄 Detalle con parted:"
parted -l
echo

# ========================
# Validar disco y particiones
# ========================
if [[ ! -b $DISK ]]; then
    echo "❌ El disco $DISK no existe."
    exit 1
fi
if [[ ! -b $PART_RESIZE ]]; then
    echo "❌ La partición a redimensionar $PART_RESIZE no existe."
    exit 1
fi

# ========================
# Confirmación
# ========================
echo "⚠️  Se eliminará $PART_DEL y se redimensionará $PART_RESIZE en $DISK."
read -rp "¿Deseas continuar? (sí/no): " confirm
if [[ "$confirm" != "sí" && "$confirm" != "SI" ]]; then
    echo "❌ Operación cancelada."
    exit 0
fi

# ========================
# Proceso
# ========================
echo "🔹 Desmontando $PART_DEL si está montada..."
umount "$PART_DEL" 2>/dev/null || echo "$PART_DEL no estaba montada."

# Validar que realmente esté desmontada
if mount | grep -q "^$PART_DEL "; then
    echo "❌ La partición $PART_DEL sigue montada. Por favor, desmonta manualmente antes de continuar."
    exit 1
fi

echo "🔹 Eliminando $PART_DEL..."
parted "$DISK" rm "${PART_DEL//[^0-9]/}"

echo "🔹 Redimensionando $PART_RESIZE para ocupar todo el disco..."
parted "$DISK" resizepart "${PART_RESIZE//[^0-9]/}" 100%

echo "🔹 Ajustando el sistema de archivos..."
e2fsck -f "$PART_RESIZE"
resize2fs "$PART_RESIZE"

echo "✅ ¡Proceso completado! Reinicia tu sistema."
