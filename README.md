# Auditoria de Cuentas Administrativas Locales - Documentacion Operativa

Script principal: `local-admin-audit.ps1`

## Objetivo
Listar miembros de `Administrators`, comparar contra whitelist y alertar cuentas no autorizadas.

## Funcionamiento
1. Valida cmdlet `Get-LocalGroupMember`.
2. Obtiene miembros del grupo local `Administrators`.
3. Compara cada cuenta contra `Whitelist`.
4. Genera alerta por cada cuenta fuera de politica.
5. Escribe log estructurado diario.

## Prerequisitos
- Windows Server 2019/2022
- PowerShell 5.1+
- Permisos para consultar grupos locales

## Configuracion
- `GroupName` (normalmente `Administrators`)
- `Whitelist` con cuentas permitidas exactas
- `Notification.Mail.*`
- `Notification.Telegram.*`

## Variables de entorno
- `AUTOMATION_SMTP_PASSWORD`
- `AUTOMATION_TELEGRAM_BOT_TOKEN`
- `AUTOMATION_TELEGRAM_CHAT_ID`

## Como ejecutar

```powershell
cd C:\Users\Nabetse\Downloads\server\AppletSaludo
.\local-admin-audit.ps1
```

## Programacion recomendada
- Trigger: diario (ejemplo 07:00) o cada 12h
- Ejecutar con cuenta con privilegios locales de auditoria

## Interpretacion
- Si no hay cuentas no autorizadas: estado normal
- Si hay cuentas fuera de whitelist: alerta de seguridad

## Seguridad
- Mantener whitelist versionada y aprobada
- Revisar alertas con flujo de respuesta formal
- No desactivar notificaciones
---
## ‍ Desarrollado por Isaac Esteban Haro Torres
**Ingeniero en Sistemas · Full Stack · Automatización · Data**
-  Email: zackharo1@gmail.com
-  WhatsApp: 098805517
-  GitHub: https://github.com/ieharo1
-  Portafolio: https://ieharo1.github.io/portafolio-isaac.haro/
---
##  Licencia
© 2026 Isaac Esteban Haro Torres - Todos los derechos reservados.
