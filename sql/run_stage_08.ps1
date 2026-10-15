param(
    [string]$PsqlPath = "D:\PostgreSQL\17\bin\psql.exe",
    [string]$PythonPath = "python"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$environmentFile = Join-Path $repositoryRoot ".env"
$exportDirectory = Join-Path $repositoryRoot "data\exports"
$analysisExport = Join-Path $exportDirectory "delivery_review_orders.csv"
$outputDirectory = Join-Path $repositoryRoot "python\outputs"

$settings = @{}
Get-Content -LiteralPath $environmentFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        $settings[$matches[1].Trim()] = $matches[2]
    }
}

New-Item -ItemType Directory -Force -Path $exportDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$previousPassword = $env:PGPASSWORD
Push-Location $repositoryRoot
try {
    $env:PGPASSWORD = $settings["POSTGRES_PASSWORD"]
    $databaseArguments = @(
        "-X", "-w",
        "-h", $settings["POSTGRES_HOST"],
        "-p", $settings["POSTGRES_PORT"],
        "-U", $settings["POSTGRES_USER"],
        "-d", $settings["POSTGRES_DB"],
        "-v", "ON_ERROR_STOP=1",
        "-P", "pager=off"
    )

    foreach ($relativePath in @(
        "03_marts/02_build_delivery_review_mart.sql",
        "05_quality/04_stage08_delivery_review_checks.sql"
    )) {
        Write-Host "Running $relativePath"
        & $PsqlPath @databaseArguments -f (Join-Path $PSScriptRoot $relativePath)
        if ($LASTEXITCODE -ne 0) {
            throw "SQL execution failed: $relativePath"
        }
    }

    Write-Host "Exporting the order-level statistical dataset"
    & $PsqlPath @databaseArguments --csv -q `
        -f (Join-Path $PSScriptRoot "04_analysis/04_delivery_review_export.sql") `
        -o $analysisExport
    if ($LASTEXITCODE -ne 0) {
        throw "SQL export failed."
    }

    Write-Host "Running Python statistical analysis"
    & $PythonPath "python/src/run_statistical_analysis.py" `
        --input $analysisExport `
        --output-dir $outputDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Python statistical analysis failed."
    }

    Write-Host "Running statistical utility tests"
    & $PythonPath -m unittest discover -s python/tests -p "test_*.py" -v
    if ($LASTEXITCODE -ne 0) {
        throw "Python tests failed."
    }
}
finally {
    $env:PGPASSWORD = $previousPassword
    Pop-Location
}

Write-Host "Stage 08 completed successfully."

