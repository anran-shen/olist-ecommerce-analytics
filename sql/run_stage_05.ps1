param(
    [string]$PsqlPath = "D:\PostgreSQL\17\bin\psql.exe"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$environmentFile = Join-Path $repositoryRoot ".env"

if (-not (Test-Path -LiteralPath $PsqlPath)) {
    throw "PostgreSQL client not found: $PsqlPath"
}
if (-not (Test-Path -LiteralPath $environmentFile)) {
    throw "Missing .env. Complete Stage 4 before running Stage 5."
}

$settings = @{}
Get-Content -LiteralPath $environmentFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        $settings[$matches[1].Trim()] = $matches[2]
    }
}

$required = @("POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_DB", "POSTGRES_USER", "POSTGRES_PASSWORD")
foreach ($name in $required) {
    if (-not $settings.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($settings[$name])) {
        throw "Missing required setting in .env: $name"
    }
}

$scripts = @(
    "02_core/00_build_dimensions.sql",
    "02_core/01_build_facts.sql",
    "03_marts/00_build_performance_marts.sql",
    "05_quality/01_stage05_quality_checks.sql"
)

$previousPassword = $env:PGPASSWORD
Push-Location $repositoryRoot
try {
    $env:PGPASSWORD = $settings["POSTGRES_PASSWORD"]
    foreach ($relativePath in $scripts) {
        $hostPath = Join-Path $PSScriptRoot $relativePath
        Write-Host "Running $relativePath"
        & $PsqlPath -X -w `
            -h $settings["POSTGRES_HOST"] `
            -p $settings["POSTGRES_PORT"] `
            -U $settings["POSTGRES_USER"] `
            -d $settings["POSTGRES_DB"] `
            -v ON_ERROR_STOP=1 `
            -f $hostPath
        if ($LASTEXITCODE -ne 0) {
            throw "SQL execution failed: $relativePath"
        }
    }
}
finally {
    $env:PGPASSWORD = $previousPassword
    Pop-Location
}

Write-Host "Stage 05 completed successfully."

