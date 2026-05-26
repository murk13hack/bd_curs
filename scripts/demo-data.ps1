# Накатывание / удаление демонстрационного набора данных ПТТ.
# Требует запущенный контейнер ptt-db (docker compose up -d).
param(
    [Parameter(Position = 0)]
    [ValidateSet("seed", "wipe", "status")]
    [string]$Action = "seed",

    [string]$Container = "ptt-db",
    [string]$User = "ptt",
    [string]$Database = "ptt",

    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$DemoDir = Join-Path $Root "db\demo"

function Invoke-DemoSql {
    param([string]$FileName)
    $path = Join-Path $DemoDir $FileName
    if (-not (Test-Path $path)) {
        Write-Error "File not found: $path"
    }
    Write-Host "Running $FileName ..."
    docker cp $path "${Container}:/tmp/$FileName"
    docker exec $Container psql -U $User -d $Database -v ON_ERROR_STOP=1 -f "/tmp/$FileName"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Get-DemoStatus {
    $q = "SELECT CASE WHEN EXISTS (SELECT 1 FROM app_settings WHERE user_id=1 AND key='_demo_dataset') THEN 'loaded' ELSE 'empty' END;"
    docker exec $Container psql -U $User -d $Database -t -A -c $q
}

switch ($Action) {
    "status" {
        $state = Get-DemoStatus
        if ($state -eq "loaded") {
            docker exec $Container psql -U $User -d $Database -c `
                "SELECT value->>'loaded_at' AS loaded_at, jsonb_array_length(value->'tasks') AS tasks, jsonb_array_length(value->'behavior_patterns') AS patterns, jsonb_array_length(value->'diary_entries') AS diary FROM app_settings WHERE user_id=1 AND key='_demo_dataset';"
        } else {
            Write-Host "Demo dataset: not loaded."
        }
    }
    "wipe" {
        Invoke-DemoSql "wipe_demo.sql"
        Write-Host "Demo data removed."
    }
    "seed" {
        $state = Get-DemoStatus
        if ($state -eq "loaded") {
            if ($Force) {
                Write-Host "Demo already loaded; -Force: wiping first..."
                Invoke-DemoSql "wipe_demo.sql"
            } else {
                Write-Error "Demo data already loaded. Use: demo-data.ps1 wipe  OR  demo-data.ps1 seed -Force"
            }
        }
        Invoke-DemoSql "seed_demo.sql"
        Write-Host "Demo data loaded. Open http://localhost/ and check dashboard, stats, patterns, diary."
    }
}
