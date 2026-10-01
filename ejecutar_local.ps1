# Corrida local del modelo original de probabilidad de recesion.
# Uso (desde esta carpeta):
#   .\ejecutar_local.ps1
#
# Los scripts de Python leen las claves del entorno, no del .env,
# asi que este script las carga antes de llamarlos.

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

# La consola de Windows usa cp1252. Sin esto, un caracter como la flecha
# del reporte tumba el proceso con UnicodeEncodeError.
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8 = "1"

if (-not (Test-Path ".env")) {
    Write-Host "No existe el archivo .env en esta carpeta." -ForegroundColor Red
    exit 1
}

Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.*)$') {
        $valor = $Matches[2].Trim().Trim('"')
        if ($valor) { Set-Item -Path "Env:$($Matches[1])" -Value $valor }
    }
}

if (-not $env:FRED_API_KEY) {
    Write-Host "FRED_API_KEY esta vacia en el archivo .env" -ForegroundColor Red
    exit 1
}

Write-Host "`n[1/2] Descargando datos, estimando el modelo y generando graficos..." -ForegroundColor Cyan
python automation/daily_report.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`n[2/2] Redactando el correo y enviando..." -ForegroundColor Cyan
python automation/generate_email.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`nListo. Resultados en automation/output/" -ForegroundColor Green
