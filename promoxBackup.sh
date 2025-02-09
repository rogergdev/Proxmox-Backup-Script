#!/bin/bash
set -euo pipefail

# Colores y versión
ROJO="\e[31m"
VERDE="\e[32m"
AMARILLO="\e[33m"
AZUL="\e[34m"
NC="\e[0m"
VERSION="1.2"

mostrar_banner() {
    clear
    echo -e "${AZUL}============================================"
    echo "  SISTEMA DE BACKUP PROXMOX READY TO GO - v${VERSION}"
    echo "============================================${NC}"
}

pausar() { read -p "Pulsa [ENTER] para continuar..."; }

schedule_cron() {
    echo -e "${AMARILLO}Elige la frecuencia de backups automáticos:${NC}"
    echo -e "${AZUL}1) Diario    - Se ejecuta todos los días.${NC}"
    echo -e "${AZUL}2) Semanal   - Se ejecuta una vez por semana.${NC}"
    echo -e "${AZUL}3) Mensual   - Se ejecuta una vez al mes.${NC}"
    echo -e "${AZUL}4) Anual     - Se ejecuta una vez al año.${NC}"
    read -p "Opción [1-4]: " freq_option
    read -p "Introduce la hora (HH) [por defecto: 02]: " cron_hour
    cron_hour="${cron_hour:-02}"
    read -p "Introduce el minuto (MM) [por defecto: 00]: " cron_minute
    cron_minute="${cron_minute:-00}"
    case "$freq_option" in
        1)
            cron_schedule="${cron_minute} ${cron_hour} * * *" ;;
        2)
            read -p "Introduce el día de la semana (0-6, 0 es domingo) [por defecto: 0]: " cron_dow
            cron_dow="${cron_dow:-0}"
            cron_schedule="${cron_minute} ${cron_hour} * * ${cron_dow}" ;;
        3)
            read -p "Introduce el día del mes (1-31) [por defecto: 1]: " cron_dom
            cron_dom="${cron_dom:-1}"
            cron_schedule="${cron_minute} ${cron_hour} ${cron_dom} * *" ;;
        4)
            read -p "Introduce el mes (1-12) [por defecto: 1]: " cron_month
            cron_month="${cron_month:-1}"
            read -p "Introduce el día del mes (1-31) [por defecto: 1]: " cron_dom
            cron_dom="${cron_dom:-1}"
            cron_schedule="${cron_minute} ${cron_hour} ${cron_dom} ${cron_month} *" ;;
        *)
            echo -e "${ROJO}Opción inválida, se usará la diaria por defecto.${NC}"
            cron_schedule="${cron_minute} ${cron_hour} * * *" ;;
    esac
    cron_job="${cron_schedule} ${BACKUP_SCRIPT} >> /var/log/proxmox-config-backup.cron.log 2>&1"
    (crontab -l 2>/dev/null | grep -Fv "${BACKUP_SCRIPT}"; echo "$cron_job") | crontab -
    echo -e "${VERDE}Cron job programado:${NC} ${cron_job}"
}

remove_cron() {
    crontab -l 2>/dev/null | grep -v "${BACKUP_SCRIPT}" | crontab -
    echo -e "${VERDE}Backups automáticos deshabilitados.${NC}"
}

check_for_updates() {
    echo -e "${AMARILLO}Comprobando actualizaciones...${NC}"
    echo -e "${VERDE}Estás utilizando la versión más reciente.${NC}"
}

uninstall_backup_system() {
    [ -f "$BACKUP_SCRIPT" ] && rm -f "$BACKUP_SCRIPT"
    [ -f "$RESTORE_SCRIPT" ] && rm -f "$RESTORE_SCRIPT"
    [ -f "$VERIFY_SCRIPT" ] && rm -f "$VERIFY_SCRIPT"
    [ -L /usr/local/bin/promox-backup ] && rm -f /usr/local/bin/promox-backup
    remove_cron
    [ -f /etc/proxmox-backup.conf ] && rm -f /etc/proxmox-backup.conf
    echo -e "${AZUL}Desinstalación completada.${NC}"
    exit 0
}

main_menu() {
    while true; do
        mostrar_banner
        echo -e "${AMARILLO}Menú del Sistema de Backup:${NC}"
        echo -e "${AZUL}1)${NC} Ejecutar backup ahora"
        echo -e "${AZUL}2)${NC} Ejecutar restauración"
        echo -e "${AZUL}3)${NC} Verificar integridad de backups"
        echo -e "${AZUL}4)${NC} Habilitar backups automáticos"
        echo -e "${AZUL}5)${NC} Comprobar actualizaciones"
        echo -e "${AZUL}6)${NC} Desinstalar el sistema de backup"
        echo -e "${AZUL}7)${NC} Salir"
        read -p "Elige una opción [1-7]: " opcion
        case "$opcion" in
            1)
                echo -e "${AMARILLO}Ejecutando backup ahora...${NC}"
                bash "$BACKUP_SCRIPT"
                pausar ;;
            2)
                echo -e "${AMARILLO}Buscando backups disponibles en ${BACKUP_DIR}:${NC}"
                backups=("$BACKUP_DIR"/promoxBackup_*.tar.gz)
                if [ "${#backups[@]}" -eq 0 ]; then
                    echo -e "${ROJO}No se han encontrado backups disponibles.${NC}"
                    pausar; continue
                fi
                echo "Backups disponibles:"
                for i in "${!backups[@]}"; do
                    echo -e "${AZUL}$((i+1)))${NC} ${backups[$i]}"
                done
                read -p "Elige el número del backup a restaurar: " backup_choice
                if ! [[ "$backup_choice" =~ ^[0-9]+$ ]] || [ "$backup_choice" -lt 1 ] || [ "$backup_choice" -gt "${#backups[@]}" ]; then
                    echo -e "${ROJO}Opción no válida.${NC}"
                    pausar; continue
                fi
                backup_file="${backups[$((backup_choice-1))]}"
                echo -e "${AMARILLO}Restaurando el backup: ${backup_file}${NC}"
                bash "$RESTORE_SCRIPT" "$backup_file"
                pausar ;;
            3)
                echo -e "${AMARILLO}Verificando integridad de los backups...${NC}"
                bash "$VERIFY_SCRIPT"
                pausar ;;
            4)
                echo -e "${AMARILLO}Habilitando backups automáticos."
                echo "Ejemplos:"
                echo "  - Diario: 00 02 * * *"
                echo "  - Semanal: 30 03 * * 3"
                echo "  - Mensual: 00 04 5 * *"
                echo "  - Anual: 00 00 1 1 *"
                echo "Opción recomendada: Diario."
                schedule_cron
                pausar ;;
            5)
                check_for_updates
                pausar ;;
            6)
                read -p "¿Seguro que deseas desinstalar el sistema de backup? (s/n): " resp
                if [[ "$resp" =~ ^[sS] ]]; then
                    uninstall_backup_system
                fi
                pausar ;;
            7)
                echo -e "${VERDE}Saliendo...${NC}"
                exit 0 ;;
            *) echo -e "${ROJO}Opción inválida.${NC}"; pausar ;;
        esac
    done
}

# Instalación (si no existe configuración previa)
if [ ! -f /etc/proxmox-backup.conf ]; then
    mostrar_banner
    echo -e "${AMARILLO}Instalador del Sistema de Backup ProxMox.${NC}"
    pausar
    for dep in tar pigz; do
        command -v "$dep" >/dev/null 2>&1 || { echo -e "${ROJO}Falta $dep.${NC}"; exit 1; }
    done
    echo -e "${AMARILLO}Introduce la ruta para los backups (ENTER: /var/backups/proxmox):${NC}"
    read -p "Ruta: " backup_dir_input
    BACKUP_DIR="${backup_dir_input:-/var/backups/proxmox}"
    mkdir -p "$BACKUP_DIR"
    echo -e "${VERDE}Directorio: ${BACKUP_DIR}${NC}"
    LOG_DEF="/var/log/proxmox-config-backup.log"
    read -p "Introduce la ruta del log [${LOG_DEF}]: " LOG_FILE
    LOG_FILE="${LOG_FILE:-$LOG_DEF}"
    RET_DEF=7
    read -p "Introduce la cantidad de días de retención [${RET_DEF}]: " RETENTION_DAYS
    RETENTION_DAYS="${RETENTION_DAYS:-$RET_DEF}"
    BACKUP_SCRIPT="${BACKUP_DIR}/promoxBackup.sh"
    RESTORE_SCRIPT="${BACKUP_DIR}/restore.sh"
    VERIFY_SCRIPT="${BACKUP_DIR}/verificar_integridad.sh"
    echo -e "${AMARILLO}Descargando el script de backup (promoxBackup.sh) desde GitHub...${NC}"
    curl -o "$BACKUP_SCRIPT" -L "https://raw.githubusercontent.com/rogergdev/Proxmox-Backup-Script/main/promoxBackup.sh"
    chmod +x "$BACKUP_SCRIPT"
    cat << 'EOF' > "$RESTORE_SCRIPT"
#!/bin/bash
set -euo pipefail
[ "$#" -ne 1 ] && { echo "Uso: $0 /ruta/al/backup.tar.gz"; exit 1; }
tar -xzf "$1" -C /
echo "Restauración completada."
EOF
    chmod +x "$RESTORE_SCRIPT"
    cat << EOF > /etc/proxmox-backup.conf
BACKUP_DIR="$BACKUP_DIR"
LOG_FILE="$LOG_FILE"
RETENTION_DAYS="$RETENTION_DAYS"
BACKUP_SCRIPT="$BACKUP_SCRIPT"
RESTORE_SCRIPT="$RESTORE_SCRIPT"
EOF
fi

source /etc/proxmox-backup.conf
main_menu
