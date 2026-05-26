# Apply SQL migrations to running ptt-db container (existing volume only).
# Default: migrations 007+ (safe for upgraded DBs). Use -All only on empty/dev DBs.
param(
    [string]$Container = "ptt-db",
    [string]$User = "ptt",
    [string]$Database = "ptt",
    [switch]$All
)

$Root = Split-Path -Parent $PSScriptRoot
$Migrations = Join-Path $Root "db\migrations"

Get-ChildItem $Migrations -Filter "*.sql" | Sort-Object Name | ForEach-Object {
    $base = $_.BaseName
    $num = ($base -split '_')[0]
    if (-not $All) {
        if ($num -notmatch '^\d+$' -or [int]$num -lt 7) {
            return
        }
    }
    Write-Host "Applying $($_.Name)..."
    docker cp $_.FullName "${Container}:/tmp/$($_.Name)"
    docker exec $Container psql -U $User -d $Database -v ON_ERROR_STOP=1 -f "/tmp/$($_.Name)"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Migrations applied (mode: $(if ($All) { 'all' } else { '007+' }))."
