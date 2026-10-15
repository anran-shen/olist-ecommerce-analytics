param(
    [string]$PsqlPath = "D:\PostgreSQL\17\bin\psql.exe"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$environmentFile = Join-Path $repositoryRoot ".env"

$settings = @{}
Get-Content -LiteralPath $environmentFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        $settings[$matches[1].Trim()] = $matches[2]
    }
}

$scripts = @(
    "04_analysis/00_build_performance_diagnostics.sql",
    "05_quality/02_stage06_diagnostic_checks.sql",
    "04_analysis/01_business_performance_queries.sql",
    "04_analysis/02_growth_and_concentration_queries.sql"
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
            -P pager=off `
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

Write-Host "Stage 06 completed successfully."
