# Apply pending SQL migrations to running ptt-db container.
param(
    [string]$Container = "ptt-db",
    [string]$User = "ptt",
    [string]$Database = "ptt"
)

$Root = Split-Path -Parent $PSScriptRoot
$Migrations = Join-Path $Root "db\migrations"

Get-ChildItem $Migrations -Filter "*.sql" | Sort-Object Name | ForEach-Object {
    Write-Host "Applying $($_.Name)..."
    docker cp $_.FullName "${Container}:/tmp/$($_.Name)"
    docker exec $Container psql -U $User -d $Database -f "/tmp/$($_.Name)"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "All migrations applied."
