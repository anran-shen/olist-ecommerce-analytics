param(
    [string]$PsqlPath = "D:\PostgreSQL\17\bin\psql.exe"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$environmentFile = Join-Path $repositoryRoot ".env"

& (Join-Path $PSScriptRoot "setup_local_postgres.ps1") -PsqlPath $PsqlPath
if ($LASTEXITCODE -ne 0) { throw "Local PostgreSQL setup failed." }

$settings = @{}
Get-Content -LiteralPath $environmentFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        $settings[$matches[1].Trim()] = $matches[2]
    }
}

$hostName = $settings["POSTGRES_HOST"]
$port = $settings["POSTGRES_PORT"]
$database = $settings["POSTGRES_DB"]
$user = $settings["POSTGRES_USER"]
$previousPassword = $env:PGPASSWORD

$scripts = @(
    "00_setup/00_create_schemas.sql",
    "01_staging/00_create_raw_tables.sql",
    "01_staging/01_load_raw_data.sql",
    "01_staging/02_create_staging_views.sql",
    "05_quality/00_stage04_quality_checks.sql"
)

Push-Location $repositoryRoot
try {
    $env:PGPASSWORD = $settings["POSTGRES_PASSWORD"]
    foreach ($relativePath in $scripts) {
        $hostPath = Join-Path $PSScriptRoot $relativePath
        Write-Host "Running $relativePath"
        & $PsqlPath -X -w -h $hostName -p $port -U $user -d $database `
            -v ON_ERROR_STOP=1 -f $hostPath
        if ($LASTEXITCODE -ne 0) {
            throw "SQL execution failed: $relativePath"
        }
    }
}
finally {
    $env:PGPASSWORD = $previousPassword
    Pop-Location
}

Write-Host "Stage 04 completed successfully."

