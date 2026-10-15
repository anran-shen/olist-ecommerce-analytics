param(
    [string]$PsqlPath = "D:\PostgreSQL\17\bin\psql.exe"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$environmentFile = Join-Path $repositoryRoot ".env"
$exportDirectory = Join-Path $repositoryRoot "data\exports\powerbi"

$settings = @{}
Get-Content -LiteralPath $environmentFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        $settings[$matches[1].Trim()] = $matches[2]
    }
}

New-Item -ItemType Directory -Force -Path $exportDirectory | Out-Null

$exports = @(
    @{ File = "pbi_months.csv"; Table = "mart.pbi_months" },
    @{ File = "pbi_orders.csv"; Table = "mart.pbi_orders" },
    @{ File = "pbi_order_items.csv"; Table = "mart.pbi_order_items" },
    @{ File = "pbi_customers.csv"; Table = "mart.pbi_customers" },
    @{ File = "monthly_business_kpis.csv"; Table = "mart.monthly_business_kpis" },
    @{ File = "monthly_kpi_decomposition.csv"; Table = "mart.monthly_kpi_decomposition" },
    @{ File = "monthly_category_gmv_change.csv"; Table = "mart.monthly_category_gmv_change" },
    @{ File = "monthly_state_gmv_change.csv"; Table = "mart.monthly_state_gmv_change" },
    @{ File = "monthly_seller_gmv_change.csv"; Table = "mart.monthly_seller_gmv_change" },
    @{ File = "cohort_retention.csv"; Table = "mart.cohort_retention" },
    @{ File = "cohort_repeat_90d.csv"; Table = "mart.cohort_repeat_90d" }
)

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
        "03_marts/03_build_powerbi_views.sql",
        "05_quality/05_stage10_powerbi_checks.sql"
    )) {
        Write-Host "Running $relativePath"
        & $PsqlPath @databaseArguments -f (Join-Path $PSScriptRoot $relativePath)
        if ($LASTEXITCODE -ne 0) {
            throw "SQL execution failed: $relativePath"
        }
    }

    foreach ($export in $exports) {
        $outputPath = Join-Path $exportDirectory $export.File
        Write-Host "Exporting $($export.Table)"
        & $PsqlPath @databaseArguments --csv -q `
            -c "SELECT * FROM $($export.Table)" `
            -o $outputPath
        if ($LASTEXITCODE -ne 0) {
            throw "Power BI export failed: $($export.Table)"
        }
    }
}
finally {
    $env:PGPASSWORD = $previousPassword
    Pop-Location
}

Write-Host "Stage 10 data preparation completed successfully."

