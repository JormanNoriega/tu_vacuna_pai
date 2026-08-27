#requires -Version 5.1
<#
    smoke-provisioning.ps1
    ======================
    Smoke E2E del aprovisionamiento de usuarios (idempotencia por operationId).

    Requiere un admin real (SUPER_ADMIN o ADMIN_INSTITUTION con USER_MANAGE):
      * SUPABASE_URL          -> https://jfxkrznzhfvecaaixkjv.supabase.co
      * SUPABASE_ANON_KEY     -> anon/publishable key del proyecto (login en Supabase Auth)
      * SMOKE_ADMIN_EMAIL     -> admin que ejecuta la creacion
      * SMOKE_ADMIN_PASSWORD  -> contrasena de ese admin (SOLO local, nunca se imprime)

    Opcional:
      * API_BASE             -> base de la API (default http://localhost:8080/api/v1)
      * PAI_SMOKE_DB_URL     -> URL de BD para verificacion en BD + limpieza completa.
                                Requiere psql en el PATH. Si no se provee, el recurso de
                                prueba queda creado y el script indica como limpiarlo.

    Credenciales: se leen de variables de entorno del proceso o de scripts/.env.smoke
    (gitignored). Tambien se respeta services/api/.env.local para DB_URL.

    Uso:
      Copy-Item scripts/smoke.env.example scripts/.env.smoke   # completa los valores
      .\scripts\smoke-provisioning.ps1

    Seguridad: nunca se imprime la contrasena ni el JWT. El recurso de prueba usa un
    correo identificable (smoke.<timestamp>@pai.test) y se limpia al terminar cuando
    hay acceso a BD.
#>

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $scriptDir

# ---------------------------------------------------------------------------
# Carga de config: variable de entorno > scripts/.env.smoke > services/api/.env.local > default
# ---------------------------------------------------------------------------
$fileVars = @{}

function Load-DotEnv([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    Get-Content -LiteralPath $path | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
                $k = $Matches[1]
                $v = $Matches[2].Trim()
                if ($v.Length -ge 2 -and (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'")))) {
                    $v = $v.Substring(1, $v.Length - 2)
                }
                $fileVars[$k] = $v
            }
        }
    }
}

function Get-Config([string]$name, [string]$default = '') {
    $envValue = [Environment]::GetEnvironmentVariable($name)
    if (-not [string]::IsNullOrWhiteSpace($envValue)) { return $envValue }
    if ($fileVars.ContainsKey($name)) { return $fileVars[$name] }
    return $default
}

Load-DotEnv (Join-Path $repoRoot 'services\api\.env.local')
Load-DotEnv (Join-Path $scriptDir '.env.smoke')

$supabaseUrl = (Get-Config 'SUPABASE_URL' 'https://jfxkrznzhfvecaaixkjv.supabase.co').TrimEnd('/')
$apiBase     = (Get-Config 'API_BASE' 'http://localhost:8080/api/v1').TrimEnd('/')
$anonKey     = Get-Config 'SUPABASE_ANON_KEY'
$adminEmail  = Get-Config 'SMOKE_ADMIN_EMAIL'
$adminPass   = Get-Config 'SMOKE_ADMIN_PASSWORD'
$dbUrl       = Get-Config 'PAI_SMOKE_DB_URL'

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
function Invoke-Api {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers,
        [object]$Body
    )
    try {
        $params = @{
            Method        = $Method
            Uri           = $Uri
            Headers       = $Headers
            ErrorAction   = 'Stop'
            UseBasicParsing = $true
        }
        if ($null -ne $Body) {
            $params.ContentType = 'application/json'
            $params.Body = ($Body | ConvertTo-Json -Compress)
        }
        $resp = Invoke-WebRequest @params
        $data = $null
        if ($resp.Content) { $data = $resp.Content | ConvertFrom-Json }
        return @{ Status = [int]$resp.StatusCode; Data = $data }
    }
    catch {
        $status = 0
        $data   = $null
        $resp   = $_.Exception.Response
        if ($null -ne $resp) {
            $status = [int]$resp.StatusCode
            try {
                $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
                $raw = $reader.ReadToEnd()
                if ($raw) { $data = $raw | ConvertFrom-Json }
            }
            catch { $data = $null }
        }
        return @{ Status = $status; Data = $data }
    }
}

function Mask-Email([string]$email) {
    if ([string]::IsNullOrWhiteSpace($email)) { return '(no configurado)' }
    $at = $email.IndexOf('@')
    if ($at -le 0) { return '***' }
    $local = $email.Substring(0, [Math]::Min(2, $at))
    return ($local + '***@' + $email.Substring($at + 1))
}

function Api-Detail($data) {
    if ($null -eq $data) { return '' }
    $err  = $data.error
    $msg  = $data.message
    return ("error=$err message=$msg").Trim()
}

$results = New-Object System.Collections.Generic.List[object]
function Add-Result([string]$check, [bool]$ok, [string]$detail) {
    $label = if ($ok) { 'PASS' } else { 'FAIL' }
    $results.Add([pscustomobject]@{ Check = $check; Status = $label; Detail = $detail })
    Write-Host ("[{0}] {1} :: {2}" -f $label, $check, $detail)
}

$cleanupNote = $null
$createdId   = $null
$opId1       = $null
$opId2       = $null
$email       = $null

# ---------------------------------------------------------------------------
# Validacion de config
# ---------------------------------------------------------------------------
Write-Host '== Smoke E2E: aprovisionamiento (idempotencia por operationId) =='
Write-Host ("Admin: {0} | API: {1}" -f (Mask-Email $adminEmail), $apiBase)

if ([string]::IsNullOrWhiteSpace($anonKey)) {
    Write-Host '[FAIL] Falta SUPABASE_ANON_KEY (copia scripts/smoke.env.example a scripts/.env.smoke y completa).'
    exit 1
}
if ([string]::IsNullOrWhiteSpace($adminEmail) -or [string]::IsNullOrWhiteSpace($adminPass)) {
    Write-Host '[FAIL] Faltan SMOKE_ADMIN_EMAIL y/o SMOKE_ADMIN_PASSWORD.'
    exit 1
}

# ---------------------------------------------------------------------------
# 1. Login -> JWT (nunca se imprime)
# ---------------------------------------------------------------------------
$login = Invoke-Api 'POST' "$supabaseUrl/auth/v1/token?grant_type=password" `
    @{ apikey = $anonKey } @{ email = $adminEmail; password = $adminPass }

if ($login.Status -ne 200 -or [string]::IsNullOrWhiteSpace($login.Data.access_token)) {
    Add-Result 'Login admin' $false ("HTTP $($login.Status) " + (Api-Detail $login.Data))
    $failed = @($results | Where-Object { $_.Status -eq 'FAIL' }).Count
    Write-Host ''
    Write-Host ('== RESUMEN: {0} PASS / {1} FAIL ==' -f ($results.Count - $failed), $failed)
    exit 1
}
$accessToken = $login.Data.access_token
Add-Result 'Login admin' $true ("access_token obtenido (len $($accessToken.Length))")

$apiHeaders = @{ Authorization = "Bearer $accessToken" }

# ---------------------------------------------------------------------------
# 2. Recurso de prueba identificable
# ---------------------------------------------------------------------------
$stamp        = Get-Date -Format 'yyyyMMddHHmmss'
$email        = "smoke.$stamp@pai.test"
$fullName     = 'Smoke Test User'
$tempPassword = 'SmokeTemp#2026!Xy'
$opId1        = [Guid]::NewGuid().ToString()
$opId2        = [Guid]::NewGuid().ToString()

Write-Host ''
Write-Host ("Recurso de prueba: {0} (opId1={1})" -f $email, $opId1)

# ---------------------------------------------------------------------------
# 3. Crear vacunador con operationId nuevo -> 201
# ---------------------------------------------------------------------------
$create = Invoke-Api 'POST' "$apiBase/users/vaccinators" $apiHeaders @{
    email            = $email
    fullName         = $fullName
    temporaryPassword = $tempPassword
    operationId      = $opId1
}
if ($create.Status -eq 201 -and $create.Data.id) {
    $createdId = $create.Data.id
    Add-Result 'POST /users/vaccinators -> 201' $true ("id=$createdId")
}
else {
    Add-Result 'POST /users/vaccinators -> 201' $false ("HTTP $($create.Status) " + (Api-Detail $create.Data))
}

# ---------------------------------------------------------------------------
# 4. Idempotencia: mismo operationId -> 201 con el MISMO id
# ---------------------------------------------------------------------------
$replay = Invoke-Api 'POST' "$apiBase/users/vaccinators" $apiHeaders @{
    email            = $email
    fullName         = $fullName
    temporaryPassword = $tempPassword
    operationId      = $opId1
}
if ($replay.Status -eq 201 -and $replay.Data.id -eq $createdId) {
    Add-Result 'Idempotencia (mismo operationId)' $true ("mismo id=$($replay.Data.id)")
}
else {
    Add-Result 'Idempotencia (mismo operationId)' $false ("HTTP $($replay.Status) id=$($replay.Data.id) esperado=$createdId")
}

# ---------------------------------------------------------------------------
# 5. Mismo email con operationId NUEVO -> 409 EMAIL_ALREADY_EXISTS (op REJECTED)
# ---------------------------------------------------------------------------
$dup = Invoke-Api 'POST' "$apiBase/users/vaccinators" $apiHeaders @{
    email            = $email
    fullName         = $fullName
    temporaryPassword = $tempPassword
    operationId      = $opId2
}
if ($dup.Status -eq 409 -and $dup.Data.error -eq 'EMAIL_ALREADY_EXISTS') {
    Add-Result 'Duplicado email (409/REJECTED)' $true "error=$($dup.Data.error)"
}
else {
    Add-Result 'Duplicado email (409/REJECTED)' $false ("HTTP $($dup.Status) " + (Api-Detail $dup.Data))
}

# ---------------------------------------------------------------------------
# 6. Auditoria: GET /admin/users/operations contiene opId1
# ---------------------------------------------------------------------------
$ops = Invoke-Api 'GET' "$apiBase/admin/users/operations" $apiHeaders $null
if ($ops.Status -eq 200) {
    $opsList = @($ops.Data)
    $found = @($opsList | Where-Object { $_.operationId -eq $opId1 })
    if ($found.Count -ge 1) {
        Add-Result 'GET /admin/users/operations' $true ("$($opsList.Count) ops, contiene opId1")
    }
    else {
        Add-Result 'GET /admin/users/operations' $false "no contiene opId1 ($($opsList.Count) ops)"
    }
}
else {
    Add-Result 'GET /admin/users/operations' $false ("HTTP $($ops.Status) " + (Api-Detail $ops.Data))
}

# ---------------------------------------------------------------------------
# 7. Reconciliacion: POST /admin/users/reconcile -> 200
# ---------------------------------------------------------------------------
$recon = Invoke-Api 'POST' "$apiBase/admin/users/reconcile" $apiHeaders $null
if ($recon.Status -eq 200) {
    $reconCount = if ($null -eq $recon.Data) { 0 } else { @($recon.Data).Count }
    Add-Result 'POST /admin/users/reconcile -> 200' $true "$reconCount huerfanos"
}
else {
    Add-Result 'POST /admin/users/reconcile -> 200' $false ("HTTP $($recon.Status) " + (Api-Detail $recon.Data))
}

# ---------------------------------------------------------------------------
# 8. Verificacion en BD (opcional) y limpieza
# ---------------------------------------------------------------------------
$hasDb = (-not [string]::IsNullOrWhiteSpace($dbUrl)) -and $null -ne (Get-Command psql -ErrorAction SilentlyContinue)

if ($hasDb) {
    $q = "SELECT status FROM app.provisioning_operations WHERE operation_id = '$opId1' " +
         "UNION ALL SELECT status FROM app.provisioning_operations WHERE operation_id = '$opId2';"
    $out = & psql $dbUrl -At -v ON_ERROR_STOP=1 -c $q 2>$null
    if ($LASTEXITCODE -eq 0) {
        $lines = @($out)
        $ok = ($lines.Count -eq 2 -and $lines[0] -eq 'COMPLETED' -and $lines[1] -eq 'REJECTED')
        Add-Result 'BD: estados de operacion' $ok ("COMPLETED/REJECTED -> " + ($lines -join ' , '))
    }
    else {
        Add-Result 'BD: estados de operacion' $false ("psql fallo (exit $LASTEXITCODE)")
    }
}
else {
    Write-Host '[WARN] Sin acceso a BD (PAI_SMOKE_DB_URL y psql): se omite verificacion en BD.'
}

# Limpieza: app.user_roles -> app.users -> auth.users (la FK app.users->auth.users exige ese orden)
if (-not $createdId) {
    Write-Host '[WARN] No se creo recurso; no hay nada que limpiar.'
}
elseif ($hasDb) {
    $sql = @"
DELETE FROM app.user_roles             WHERE user_id = '$createdId';
DELETE FROM app.provisioning_operations WHERE auth_user_id = '$createdId' OR operation_id IN ('$opId1','$opId2');
DELETE FROM app.users                   WHERE id = '$createdId';
DELETE FROM auth.users                  WHERE id = '$createdId';
"@
    $tmpFile = Join-Path $env:TEMP ("smoke-cleanup-$([Guid]::NewGuid().ToString()).sql")
    Set-Content -LiteralPath $tmpFile -Value $sql -Encoding ASCII
    $null = & psql $dbUrl -v ON_ERROR_STOP=1 -f $tmpFile 2>&1
    $rc = $LASTEXITCODE
    Remove-Item -LiteralPath $tmpFile -ErrorAction SilentlyContinue
    if ($rc -eq 0) {
        Add-Result 'Limpieza (auth + app.users)' $true 'recurso de prueba eliminado'
    }
    else {
        Add-Result 'Limpieza (auth + app.users)' $false ("psql exit $rc")
        $cleanupNote = "Limpieza fallida: elimina manualmente el correo $email (ver SQL en el script)."
    }
}
else {
    $cleanupNote = "Recurso $email queda creado (sin PAI_SMOKE_DB_URL/psql no hay limpieza automatica). " +
                   "Para eliminarlo: DELETE app.user_roles, app.users y auth.users con id=$createdId (en ese orden)."
    Write-Host "[WARN] $cleanupNote"
}

# ---------------------------------------------------------------------------
# 9. Resumen
# ---------------------------------------------------------------------------
$failed = @($results | Where-Object { $_.Status -eq 'FAIL' }).Count
$passed = $results.Count - $failed
Write-Host ''
Write-Host ('== RESUMEN: {0} PASS / {1} FAIL ==' -f $passed, $failed)
if ($cleanupNote) {
    Write-Host "[WARN] $cleanupNote"
}
if ($failed -gt 0) { exit 1 }
exit 0