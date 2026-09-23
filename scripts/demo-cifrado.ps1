#requires -Version 5.1
<#
    demo-cifrado.ps1
    ================
    Demo "en caliente" del cifrado de la base local (SQLite3MultipleCiphers).

    Que hace:
      1. Ejecuta la guarda de regresion: apps\mobile\test\core\storage\
         database_encryption_test.dart (4 tests: secreto fuera de texto plano,
         clave incorrecta rechazada, clave correcta lee, motor = sqlite3mc).
      2. Ejecuta la demo visual: database_encryption_demo_test.dart crea una
         base cifrada en %TEMP%, muestra el hexdump de los primeros bytes,
         el rechazo sin clave y la lectura con clave correcta.

    Requisitos:
      * flutter en el PATH. No requiere emulador ni dispositivo: todo corre
        en el host (Dart VM); el binario sqlite3mc se compila via hooks.
      * Haber corrido "flutter pub get" en apps\mobile al menos una vez.

    La base de demo queda en %TEMP%\tu_vacuna_pai_demo_cifrado\pacientes.db
    (no se limpia) para inspeccionar con editor hexadecimal o sqlite3 CLI.

    Uso:
      .\scripts\demo-cifrado.ps1
#>

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $scriptDir
$mobileDir = Join-Path $repoRoot 'apps\mobile'

function Invoke-FlutterTest([string]$testPath, [string]$label) {
    Write-Host ("-- {0}: flutter test {1} --" -f $label, $testPath)
    Push-Location $mobileDir
    try {
        & flutter test $testPath -r expanded
    }
    finally {
        Pop-Location
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("[FAIL] {0} (flutter test exit {1})" -f $label, $LASTEXITCODE)
        exit 1
    }
    Write-Host ("[PASS] {0}" -f $label)
    Write-Host ''
}

# ---------------------------------------------------------------------------
# 0. Verificacion de prerequisites
# ---------------------------------------------------------------------------
Write-Host '== Demo en caliente: cifrado de la base local (ADR-003) =='
Write-Host ''

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host '[FAIL] flutter no esta en el PATH.'
    exit 1
}
if (-not (Test-Path -LiteralPath $mobileDir)) {
    Write-Host ("[FAIL] No se encontro apps\mobile en {0}" -f $repoRoot)
    exit 1
}

# ---------------------------------------------------------------------------
# 1. Guarda de regresion del cifrado (4 tests)
# ---------------------------------------------------------------------------
Invoke-FlutterTest 'test\core\storage\database_encryption_test.dart' 'Paso 1/2 Guarda de regresion (4 tests)'

# ---------------------------------------------------------------------------
# 2. Demo visual del archivo cifrado (hexdump + sin clave + con clave)
# ---------------------------------------------------------------------------
Invoke-FlutterTest 'test\core\storage\database_encryption_demo_test.dart' 'Paso 2/2 Demo visual del archivo cifrado'

$demoDb = Join-Path $env:TEMP 'tu_vacuna_pai_demo_cifrado\pacientes.db'
if (Test-Path -LiteralPath $demoDb) {
    Write-Host ("Archivo de demo disponible para inspeccion manual: {0}" -f $demoDb)
}

Write-Host ''
Write-Host '== RESUMEN: guardas 4/4 PASS + demo 1/1 PASS =='
exit 0
