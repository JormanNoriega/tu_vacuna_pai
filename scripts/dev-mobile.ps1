#requires -Version 5.1
<#
    dev-mobile.ps1
    ==============
    Inicia la app Flutter en el celular físico conectado por USB,
    activando automáticamente el túnel de puertos (adb reverse).
#>

$ErrorActionPreference = 'Stop'

$adb = (Get-Command adb -ErrorAction SilentlyContinue)?.Source
if (-not $adb) {
    $adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
}

Write-Host "== [1/2] Configurando tunel USB (adb reverse port 8080) ==" -ForegroundColor Cyan
if (Test-Path $adb) {
    & $adb -d reverse tcp:8080 tcp:8080
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Tunel USB listo (puerto 8080 redirigido)." -ForegroundColor Green
    }
} else {
    Write-Host "[WARN] No se encontro adb.exe; asegurese de tener el SDK instalado." -ForegroundColor Yellow
}

$mobileDir = Join-Path $PSScriptRoot "..\apps\mobile"
Write-Host "== [2/2] Iniciando Flutter en 24117RN76L con http://127.0.0.1:8080/api/v1 ==" -ForegroundColor Cyan

Push-Location $mobileDir
try {
    flutter run -d 24117RN76L --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
}
finally {
    Pop-Location
}
