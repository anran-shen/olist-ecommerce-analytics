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
    throw "Missing .env. Copy .env.example to .env and fill the local credentials."
}

$settings = @{}
Get-Content -LiteralPath $environmentFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        $settings[$matches[1].Trim()] = $matches[2]
    }
}

$required = @(
    "POSTGRES_HOST",
    "POSTGRES_PORT",
    "POSTGRES_ADMIN_USER",
    "POSTGRES_ADMIN_PASSWORD",
    "POSTGRES_DB",
    "POSTGRES_USER",
    "POSTGRES_PASSWORD"
)
foreach ($name in $required) {
    if (-not $settings.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($settings[$name])) {
        throw "Missing required setting in .env: $name"
    }
}

$hostName = $settings["POSTGRES_HOST"]
$port = $settings["POSTGRES_PORT"]
$adminUser = $settings["POSTGRES_ADMIN_USER"]
$adminPassword = $settings["POSTGRES_ADMIN_PASSWORD"]
$database = $settings["POSTGRES_DB"]
$projectUser = $settings["POSTGRES_USER"]
$projectPassword = $settings["POSTGRES_PASSWORD"]

foreach ($identifier in @($adminUser, $database, $projectUser)) {
    if ($identifier -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        throw "Unsafe PostgreSQL identifier in .env: $identifier"
    }
}

$escapedRolePassword = $projectPassword.Replace("'", "''")
$temporarySql = Join-Path ([IO.Path]::GetTempPath()) ("olist-bootstrap-{0}.sql" -f [guid]::NewGuid())
$previousPassword = $env:PGPASSWORD

try {
    $env:PGPASSWORD = $adminPassword
    & $PsqlPath -X -w -h $hostName -p $port -U $adminUser -d postgres `
        -v ON_ERROR_STOP=1 -tAc "SELECT 1;" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL administrator connection failed." }

    $roleSql = @"
DO `$bootstrap`$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$projectUser') THEN
        CREATE ROLE "$projectUser" LOGIN PASSWORD '$escapedRolePassword';
    ELSE
        ALTER ROLE "$projectUser" WITH LOGIN PASSWORD '$escapedRolePassword';
    END IF;
END
`$bootstrap`$;
"@
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($temporarySql, $roleSql, $utf8WithoutBom)
    & $PsqlPath -X -w -h $hostName -p $port -U $adminUser -d postgres `
        -v ON_ERROR_STOP=1 -f $temporarySql
    if ($LASTEXITCODE -ne 0) { throw "Project role setup failed." }

    $databaseExists = & $PsqlPath -X -w -h $hostName -p $port -U $adminUser `
        -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$database';"
    if ($LASTEXITCODE -ne 0) { throw "Database existence check failed." }

    if ([string]::IsNullOrWhiteSpace($databaseExists)) {
        & $PsqlPath -X -w -h $hostName -p $port -U $adminUser -d postgres `
            -v ON_ERROR_STOP=1 -c "CREATE DATABASE `"$database`" OWNER `"$projectUser`" ENCODING 'UTF8';"
        if ($LASTEXITCODE -ne 0) { throw "Project database creation failed." }
    }
    else {
        & $PsqlPath -X -w -h $hostName -p $port -U $adminUser -d postgres `
            -v ON_ERROR_STOP=1 -c "ALTER DATABASE `"$database`" OWNER TO `"$projectUser`";"
        if ($LASTEXITCODE -ne 0) { throw "Project database ownership update failed." }
    }

    $env:PGPASSWORD = $projectPassword
    & $PsqlPath -X -w -h $hostName -p $port -U $projectUser -d $database `
        -v ON_ERROR_STOP=1 -tAc "SELECT current_database(), current_user;"
    if ($LASTEXITCODE -ne 0) { throw "Project user connection test failed." }
}
finally {
    if (Test-Path -LiteralPath $temporarySql) {
        $resolvedTemp = (Resolve-Path -LiteralPath $temporarySql).Path
        $expectedTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
        if ([IO.Path]::GetDirectoryName($resolvedTemp).TrimEnd('\') -eq $expectedTempRoot) {
            Remove-Item -LiteralPath $resolvedTemp -Force
        }
    }
    $env:PGPASSWORD = $previousPassword
}

Write-Host "Local PostgreSQL project database is ready."

