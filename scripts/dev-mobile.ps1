#requires -Version 5.1
<#
    dev-mobile.ps1
    ==============
    Inicia la app Flutter en el celular físico conectado por USB,
    activando automáticamente el túnel de puertos (adb reverse).
    Soporta los dispositivos autorizados (23117RA68G, 24117RN76L) o
    cualquier otro dispositivo conectado.
#>

param(
    [string]$DeviceId
)

$ErrorActionPreference = 'Stop'

$adbCmd = Get-Command adb -ErrorAction SilentlyContinue
if ($adbCmd) {
    $adb = $adbCmd.Source
} else {
    $adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
}

# 1. Detectar dispositivos conectados vía ADB
$connectedDevices = @()
if (Test-Path $adb) {
    $raw = & $adb devices
    foreach ($line in $raw) {
        if ($line -match "([^\s]+)\s+device$") {
            $connectedDevices += $matches[1]
        }
    }
}

# 2. Resolver qué dispositivo usar
$targetDevice = $DeviceId
if (-not $targetDevice) {
    if ($connectedDevices.Contains('23117RA68G')) {
        $targetDevice = '23117RA68G'
    } elseif ($connectedDevices.Contains('24117RN76L')) {
        $targetDevice = '24117RN76L'
    } elseif ($connectedDevices.Count -gt 0) {
        $targetDevice = $connectedDevices[0]
    } else {
        # Por defecto usar el dispositivo principal configurado
        $targetDevice = '23117RA68G'
    }
}

Write-Host "== [1/2] Configurando tunel USB para $targetDevice (adb reverse port 8080) ==" -ForegroundColor Cyan
if (Test-Path $adb) {
    & $adb -s $targetDevice reverse tcp:8080 tcp:8080 2>$null
    if ($LASTEXITCODE -ne 0) {
        # Si falló con -s, intentar reversión global
        & $adb -d reverse tcp:8080 tcp:8080 2>$null
    }
    Write-Host "[OK] Tunel USB listo (puerto 8080 redirigido)." -ForegroundColor Green
} else {
    Write-Host "[WARN] No se encontro adb.exe; asegurese de tener el SDK instalado." -ForegroundColor Yellow
}

$mobileDir = Join-Path $PSScriptRoot "..\apps\mobile"
Write-Host "== [2/2] Iniciando Flutter en $targetDevice con http://127.0.0.1:8080/api/v1 ==" -ForegroundColor Cyan

Push-Location $mobileDir
try {
    flutter run -d $targetDevice --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
}
finally {
    Pop-Location
}
