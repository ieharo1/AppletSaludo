# ===============================================================
# local-admin-audit.ps1
# Auditoría de cuentas administrativas locales contra lista blanca
# ===============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ================= CONFIG =================
$Config = @{
    ScriptName = 'Local-Admin-Audit'
    LogRoot = 'C:\Scripts\Logs\Local-Admin-Audit'
    GroupName = 'Administrators'
    Whitelist = @('BUILTIN\Administrators','NT AUTHORITY\SYSTEM',"$env:COMPUTERNAME\Administrator")
    Notification = @{
        Mail = @{ Enabled = $true; SmtpServer = 'smtp.company.local'; Port = 587; UseSsl = $true; User = 'smtp_user_placeholder'; PasswordEnvVar = 'AUTOMATION_SMTP_PASSWORD'; From = 'automation@company.local'; To = @('security@company.local') }
        Telegram = @{ Enabled = $true; BotTokenEnvVar = 'AUTOMATION_TELEGRAM_BOT_TOKEN'; ChatIdEnvVar = 'AUTOMATION_TELEGRAM_CHAT_ID' }
    }
}

# ================= LOG =================
if (-not (Test-Path -Path $Config.LogRoot)) { New-Item -Path $Config.LogRoot -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $Config.LogRoot ('{0}-{1:yyyyMMdd}.log' -f $Config.ScriptName, (Get-Date))

function Log {
    param([Parameter(Mandatory)] [string]$Message, [ValidateSet('INFO','WARN','ERROR')] [string]$Level = 'INFO', [hashtable]$Data)
    $entry = [ordered]@{ timestamp=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); level=$Level; script=$Config.ScriptName; host=$env:COMPUTERNAME; message=$Message; data=$Data }
    Add-Content -Path $LogFile -Value ($entry | ConvertTo-Json -Compress -Depth 5) -Encoding UTF8
    Write-Host ('[{0}] {1}' -f $Level, $Message)
}

function Send-Mail {
    param([Parameter(Mandatory)] [string]$Subject, [Parameter(Mandatory)] [string]$Body)
    if (-not $Config.Notification.Mail.Enabled) { return }
    try {
        $pwd = [Environment]::GetEnvironmentVariable($Config.Notification.Mail.PasswordEnvVar, 'Machine')
        if ([string]::IsNullOrWhiteSpace($pwd)) { $pwd = [Environment]::GetEnvironmentVariable($Config.Notification.Mail.PasswordEnvVar, 'Process') }
        if ([string]::IsNullOrWhiteSpace($pwd)) { throw "No existe variable '$($Config.Notification.Mail.PasswordEnvVar)'" }
        $mail = New-Object System.Net.Mail.MailMessage
        $mail.From = $Config.Notification.Mail.From
        foreach ($recipient in $Config.Notification.Mail.To) { [void]$mail.To.Add($recipient) }
        $mail.Subject = $Subject
        $mail.Body = $Body
        $smtp = New-Object System.Net.Mail.SmtpClient($Config.Notification.Mail.SmtpServer, $Config.Notification.Mail.Port)
        $smtp.EnableSsl = $Config.Notification.Mail.UseSsl
        $smtp.Credentials = New-Object System.Net.NetworkCredential($Config.Notification.Mail.User, $pwd)
        $smtp.Send($mail)
        $mail.Dispose(); $smtp.Dispose()
        Log -Message 'Notificación SMTP enviada.'
    }
    catch { Log -Message "Error SMTP: $($_.Exception.Message)" -Level 'ERROR' }
}

function Send-Telegram {
    param([Parameter(Mandatory)] [string]$Message)
    if (-not $Config.Notification.Telegram.Enabled) { return }
    try {
        $bot = [Environment]::GetEnvironmentVariable($Config.Notification.Telegram.BotTokenEnvVar, 'Machine')
        $chat = [Environment]::GetEnvironmentVariable($Config.Notification.Telegram.ChatIdEnvVar, 'Machine')
        if ([string]::IsNullOrWhiteSpace($bot)) { $bot = [Environment]::GetEnvironmentVariable($Config.Notification.Telegram.BotTokenEnvVar, 'Process') }
        if ([string]::IsNullOrWhiteSpace($chat)) { $chat = [Environment]::GetEnvironmentVariable($Config.Notification.Telegram.ChatIdEnvVar, 'Process') }
        if ([string]::IsNullOrWhiteSpace($bot) -or [string]::IsNullOrWhiteSpace($chat)) { throw 'Faltan credenciales Telegram.' }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-RestMethod -Uri ("https://api.telegram.org/bot{0}/sendMessage" -f $bot) -Method Post -Body @{ chat_id=$chat; text=$Message } | Out-Null
        Log -Message 'Notificación Telegram enviada.'
    }
    catch { Log -Message "Error Telegram: $($_.Exception.Message)" -Level 'ERROR' }
}

function Test-Prerequisites {
    if (-not (Get-Command -Name Get-LocalGroupMember -ErrorAction SilentlyContinue)) {
        throw 'Get-LocalGroupMember no está disponible en este sistema.'
    }
}

$errorsList = New-Object System.Collections.Generic.List[string]
$unauthorized = New-Object System.Collections.Generic.List[string]

Log -Message '=== INICIO LOCAL ADMIN AUDIT ==='

try {
    Test-Prerequisites
    $members = Get-LocalGroupMember -Group $Config.GroupName -ErrorAction Stop

    $whitelistSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($allowed in $Config.Whitelist) { [void]$whitelistSet.Add($allowed) }

    foreach ($member in $members) {
        $name = [string]$member.Name
        Log -Message "Miembro detectado: $name"
        if (-not $whitelistSet.Contains($name)) {
            $unauthorized.Add($name)
            Log -Message "Cuenta no autorizada detectada: $name" -Level 'WARN'
        }
    }
}
catch {
    $errorsList.Add($_.Exception.Message)
    Log -Message "Error general: $($_.Exception.Message)" -Level 'ERROR'
}

# ================= NOTIFICACION FINAL =================
if ($errorsList.Count -gt 0 -or $unauthorized.Count -gt 0) {
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($err in $errorsList) { $lines.Add("ERROR: $err") }
    foreach ($item in $unauthorized) { $lines.Add("NO AUTORIZADO: $item") }
    $message = "Local Admin Audit ($env:COMPUTERNAME)`n" + ($lines -join "`n")
    Send-Mail -Subject "ALERTA Cuentas Administrativas - $env:COMPUTERNAME" -Body $message
    Send-Telegram -Message $message
}
else {
    Send-Telegram -Message "Local Admin Audit sin desviaciones en $env:COMPUTERNAME"
}

Log -Message '=== FIN LOCAL ADMIN AUDIT ==='

# ---
# ## ‍ Desarrollado por Isaac Esteban Haro Torres
# **Ingeniero en Sistemas · Full Stack · Automatización · Data**
# -  Email: zackharo1@gmail.com
# -  WhatsApp: 098805517
# -  GitHub: https://github.com/ieharo1
# -  Portafolio: https://ieharo1.github.io/portafolio-isaac.haro/
# ---
# ##  Licencia
# © 2026 Isaac Esteban Haro Torres - Todos los derechos reservados.
