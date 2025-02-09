# Proxmox Backup Script

Sistema de backup automatizado para Proxmox que permite realizar copias de seguridad de la configuración, restaurar fácilmente, programar backups automáticos y verificar la integridad de los archivos.

---

## ✨ Características
- Realiza backups de la configuración de Proxmox.
- Opción para restaurar backups desde un listado interactivo.
- Programación de backups automáticos (diario, semanal, mensual, anual).
- Eliminación automática de backups antiguos según la configuración de retención.
- Menú interactivo fácil de usar.
- Desinstalación sencilla.

---

## 🔄 Instalación y Ejecución

Para instalar y ejecutar el script directamente desde GitHub, usa el siguiente comando:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/rogergdev/Proxmox-Backup-Script/main/promoxBackup.sh)"
```

Si el sistema de backup **ya está instalado**, abrirá el **menú principal**.
Si **no está instalado**, iniciará la configuración y descarga de los archivos necesarios.

---

## ⚡ Menú Principal

Al ejecutar el script, verás un menú interactivo con estas opciones:

```
============================================
  SISTEMA DE BACKUP PROXMOX READY TO GO - v1.2
============================================

Menú del Sistema de Backup:
1) Ejecutar backup ahora
2) Ejecutar restauración
3) Verificar integridad de backups
4) Habilitar backups automáticos
5) Comprobar actualizaciones
6) Desinstalar el sistema de backup
7) Salir
Elige una opción [1-7]:
```

Para seleccionar una opción, **introduce el número y pulsa ENTER**.

---

## 📁 Realizar un Backup Manualmente

Para ejecutar un backup manual en cualquier momento:

```bash
bash /var/backups/proxmox/promoxBackup.sh
```

Esto generará un archivo con el formato:

```
/var/backups/proxmox/promoxBackup_DD-MM-YYYY_HH-MM-SS.tar.gz
```

Ejemplo:
```
/var/backups/proxmox/promoxBackup_09-02-2025_15-30-45.tar.gz
```

Los backups antiguos se eliminan automáticamente según la configuración de retención (por defecto, **7 días**).

---

## 🔄 Restaurar un Backup

Para restaurar un backup, usa el **menú principal** y selecciona la opción `2) Ejecutar restauración`.
El script listará todos los backups disponibles y podrás elegir uno para restaurar.

Si prefieres restaurar un backup manualmente, usa:
```bash
bash /var/backups/proxmox/restore.sh /ruta/del/backup.tar.gz
```
Ejemplo:
```bash
bash /var/backups/proxmox/restore.sh /var/backups/proxmox/promoxBackup_09-02-2025_15-30-45.tar.gz
```

---

## ⌚ Programar Backups Automáticos

Para programar backups automáticos, abre el menú principal y selecciona la opción `4) Habilitar backups automáticos`. Podrás elegir la frecuencia:
- **Diario** (Recomendado)
- **Semanal**
- **Mensual**
- **Anual**

### 📊 Comprobar si está activado:
Para verificar que la programación automática está activa, ejecuta:
```bash
crontab -l
```
Si ves una línea como esta:
```
00 02 * * * /var/backups/proxmox/promoxBackup.sh >> /var/log/proxmox-config-backup.cron.log 2>&1
```
Significa que el backup automático está activado y se ejecutará **todos los días a las 02:00 AM**.

Para ejecutarlo manualmente sin esperar a la hora programada:
```bash
bash /var/backups/proxmox/promoxBackup.sh
```

---

## 🛠️ Desinstalar el Sistema de Backup

Si quieres eliminar completamente el sistema de backups:

1. Abre el script con:
```bash
bash /var/backups/proxmox/promoxBackup.sh
```
2. Selecciona la opción `6) Desinstalar el sistema de backup` y confirma la desinstalación.

Si prefieres hacerlo manualmente, ejecuta:
```bash
rm -rf /var/backups/proxmox
rm -f /etc/proxmox-backup.conf
crontab -l | grep -v 'promoxBackup.sh' | crontab -
```
Esto eliminará:
- Todos los backups.
- La configuración almacenada en `/etc/proxmox-backup.conf`.
- Cualquier tarea programada en **cron**.

---

## 🎉 Contribuir

Si deseas colaborar con mejoras en el script, puedes hacer un **fork** del repositorio y enviar un **pull request**.

---

## 📄 Licencia
Este proyecto está bajo la licencia **MIT**. Puedes usarlo y modificarlo libremente.

