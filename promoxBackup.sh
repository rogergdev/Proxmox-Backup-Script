#!/bin/bash
set -euo pipefail

ROJO="\e[31m"
VERDE="\e[32m"
AMARILLO="\e[33m"
AZUL="\e[34m"
NC="\e[0m"
VERSION="1.1"

mostrar_banner() {
    clear
    echo -e "${AZUL}============================================"
    echo "  SISTEMA DE BACKUP PROXMOX READY TO GO - v${VERSION}"
    echo "============================================${NC}"
}
pausar() { read -p "Presiona [ENTER] para continuar..."; }
schedule_cron() {
    cron_job="0 2 * * * ${BACKUP_SCRIPT} >> /var/log/proxmox-config-backup.cron.log 2>&1"
    (crontab -l 2>/dev/null | grep -Fv "${BACKUP_SCRIPT}"; echo "$cron_job") | crontab -
}
remove_cron() { crontab -l 2>/dev/null | grep -v "${BACKUP_SCRIPT}" | crontab -; }
check_for_updates() {
    echo -e "${AMARILLO}Actualizando script de backup desde GitHub...${NC}"
    curl -o "$BACKUP_SCRIPT" -L "https://raw.githubusercontent.com/rogergdev/Proxmox-Backup-Script/main/promoxBackup.sh"
    chmod +x "$BACKUP_SCRIPT"
    echo -e "${VERDE}Script actualizado.${NC}"
}
uninstall_backup_system() {
    [ -f "$BACKUP_SCRIPT" ] && rm -f "$BACKUP_SCRIPT"
    [ -f "$RESTORE_SCRIPT" ] && rm -f "$RESTORE_SCRIPT"
    [ -f "$VERIFY_SCRIPT" ] && rm -f "$VERIFY_SCRIPT"
    [ -L /usr/local/bin/proxmox-backup ] && rm -f /usr/local/bin/proxmox-backup
    remove_cron
    [ -f /etc/proxmox-backup.conf ] && rm -f /etc/proxmox-backup.conf
    echo -e "${AZUL}Desinstalación completada.${NC}"
    exit 0
}
main_menu() {
    while true; do
        mostrar_banner
        echo -e "${AMARILLO}Menú:${NC}"
        echo -e "${AZUL}1)${NC} Ejecutar backup"
        echo -e "${AZUL}2)${NC} Ejecutar restauración"
        echo -e "${AZUL}3)${NC} Verificar integridad"
        echo -e "${AZUL}4)${NC} Programar/Desprogramar backups automáticos"
        echo -e "${AZUL}5)${NC} Actualizar script de backup"
        echo -e "${AZUL}6)${NC} Desinstalar"
        echo -e "${AZUL}7)${NC} Salir"
        read -p "Elige [1-7]: " opcion
        case "$opcion" in
            1) bash "$BACKUP_SCRIPT"; pausar ;;
            2) read -p "Ingresa la ruta del backup a restaurar: " rb; bash "$RESTORE_SCRIPT" "$rb"; pausar ;;
            3) bash "$VERIFY_SCRIPT"; pausar ;;
            4) read -p "Activar (a) o desactivar (d) backups automáticos? [a/d]: " cron_opcion; [[ "$cron_opcion" =~ ^[aA] ]] && schedule_cron || [[ "$cron_opcion" =~ ^[dD] ]] && remove_cron; pausar ;;
            5) check_for_updates; pausar ;;
            6) read -p "¿Seguro desinstalar? (s/n): " resp; [[ "$resp" =~ ^[sS] ]] && uninstall_backup_system; pausar ;;
            7) echo -e "${VERDE}Saliendo...${NC}"; exit 0 ;;
            *) echo -e "${ROJO}Opción inválida.${NC}"; pausar ;;
        esac
    done
}

if [ -f /etc/proxmox-backup.conf ]; then
    source /etc/proxmox-backup.conf
    main_menu
fi

mostrar_banner
echo -e "${AMARILLO}Instalador del Sistema de Backup Proxmox.${NC}"
pausar

for dep in tar pigz sha256sum curl; do
    command -v "$dep" >/dev/null 2>&1 || { echo -e "${ROJO}Falta $dep.${NC}"; exit 1; }
done

echo -e "${AMARILLO}Ingresa la ruta para los backups (ENTER: /var/backups/proxmox):${NC}"
read -p "Ruta: " backup_dir_input
BACKUP_DIR="${backup_dir_input:-/var/backups/proxmox}"
mkdir -p "$BACKUP_DIR"
echo -e "${VERDE}Directorio: ${BACKUP_DIR}${NC}"

LOG_DEF="/var/log/proxmox-config-backup.log"
read -p "Ruta del log [${LOG_DEF}]: " LOG_FILE
LOG_FILE="${LOG_FILE:-$LOG_DEF}"

RET_DEF=7
read -p "Días de retención [${RET_DEF}]: " RETENTION_DAYS
RETENTION_DAYS="${RETENTION_DAYS:-$RET_DEF}"

BACKUP_SCRIPT="${BACKUP_DIR}/promoxBackup.sh"
RESTORE_SCRIPT="${BACKUP_DIR}/restore.sh"
VERIFY_SCRIPT="${BACKUP_DIR}/verificar_integridad.sh"

echo -e "${AMARILLO}Descargando script de backup desde GitHub...${NC}"
curl -o "$BACKUP_SCRIPT" -L "https://raw.githubusercontent.com/rogergdev/Proxmox-Backup-Script/main/promoxBackup.sh"
chmod +x "$BACKUP_SCRIPT"

echo -e "${AMARILLO}Instalando script de restauración...${NC}"
cat << 'EOF' > "$RESTORE_SCRIPT"
#!/bin/bash
set -euo pipefail
[ "$EUID" -ne 0 ] && { echo "Se requiere root."; exit 1; }
[ "$#" -ne 1 ] && { echo "Uso: $0 /ruta/al/backup.tar.gz"; exit 1; }
BACKUP_FILE="$1"
[ ! -f "$BACKUP_FILE" ] && { echo "No existe $BACKUP_FILE."; exit 1; }
tar -xzvf "$BACKUP_FILE" -C /
systemctl restart pve-cluster pvedaemon
echo "Restauración completada."
EOF
chmod +x "$RESTORE_SCRIPT"

echo -e "${AMARILLO}Instalando script de verificación de integridad...${NC}"
cat << 'EOF' > "$VERIFY_SCRIPT"
#!/bin/bash
set -euo pipefail
for file in ${BACKUP_DIR}/proxmox-config-backup-*.tar.gz; do
  [ -f "$file.sha256" ] && sha256sum -c "$file.sha256" || echo "No hay checksum para $file"
done
echo "Verificación completada."
EOF
chmod +x "$VERIFY_SCRIPT"

echo -e "${AMARILLO}¿Crear enlace en /usr/local/bin? (s/n):${NC}"
read -p "Respuesta: " crear_enlace
[[ "$crear_enlace" =~ ^[sS] ]] && ln -sf "$BACKUP_SCRIPT" /usr/local/bin/proxmox-backup

echo -e "${AMARILLO}¿Programar backups automáticos? (s/n):${NC}"
read -p "Respuesta: " programar_cron
[[ "$programar_cron" =~ ^[sS] ]] && schedule_cron

echo -e "${AMARILLO}¿Actualizar script de backup? (s/n):${NC}"
read -p "Respuesta: " buscar_actualizaciones
[[ "$buscar_actualizaciones" =~ ^[sS] ]] && check_for_updates

cat <<EOF > /etc/proxmox-backup.conf
BACKUP_DIR="$BACKUP_DIR"
LOG_FILE="$LOG_FILE"
RETENTION_DAYS="$RETENTION_DAYS"
BACKUP_SCRIPT="$BACKUP_SCRIPT"
RESTORE_SCRIPT="$RESTORE_SCRIPT"
VERIFY_SCRIPT="$VERIFY_SCRIPT"
EOF

echo -e "${AZUL}Instalación completada.${NC}"
pausar
main_menu
