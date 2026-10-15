param(
    [string]$PsqlPath = "D:\PostgreSQL\17\bin\psql.exe",
    [string]$PythonPath = "python"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$environmentFile = Join-Path $repositoryRoot ".env"
$exportDirectory = Join-Path $repositoryRoot "data\exports"
$capacityExport = Join-Path $exportDirectory "ab_test_monthly_capacity.csv"
$stage08Results = Join-Path $PSScriptRoot "outputs\stage08_results.json"
$outputDirectory = Join-Path $PSScriptRoot "outputs"

$settings = @{}
Get-Content -LiteralPath $environmentFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        $settings[$matches[1].Trim()] = $matches[2]
    }
}

New-Item -ItemType Directory -Force -Path $exportDirectory | Out-Null

$previousPassword = $env:PGPASSWORD
Push-Location $repositoryRoot
try {
    $env:PGPASSWORD = $settings["POSTGRES_PASSWORD"]
    Write-Host "Exporting historical experiment-planning capacity"
    & $PsqlPath -X -w `
        -h $settings["POSTGRES_HOST"] `
        -p $settings["POSTGRES_PORT"] `
        -U $settings["POSTGRES_USER"] `
        -d $settings["POSTGRES_DB"] `
        -v ON_ERROR_STOP=1 `
        -P pager=off `
        --csv -q `
        -f (Join-Path $repositoryRoot "sql\04_analysis\05_ab_test_planning_inputs.sql") `
        -o $capacityExport
    if ($LASTEXITCODE -ne 0) {
        throw "A/B test planning-input export failed."
    }

    Write-Host "Generating the A/B test design"
    & $PythonPath "python/src/design_ab_test.py" `
        --stage08-results $stage08Results `
        --monthly-capacity $capacityExport `
        --output-dir $outputDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "A/B test design generation failed."
    }

    Write-Host "Running Python unit tests"
    & $PythonPath -m unittest discover -s python/tests -p "test_*.py" -v
    if ($LASTEXITCODE -ne 0) {
        throw "Python tests failed."
    }
}
finally {
    $env:PGPASSWORD = $previousPassword
    Pop-Location
}

Write-Host "Stage 09 completed successfully."

