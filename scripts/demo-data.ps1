# Накатывание / удаление демонстрационного набора данных ПТТ.
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

if (Test-Path (Join-Path $Root ".env")) {
    Get-Content (Join-Path $Root ".env") | ForEach-Object {
        if ($_ -match '^\s*POSTGRES_USER=(.+)$') { $User = $Matches[1].Trim() }
        if ($_ -match '^\s*POSTGRES_DB=(.+)$') { $Database = $Matches[1].Trim() }
    }
}

function Invoke-DemoSql {
    param([string]$FileName)
    $path = Join-Path $DemoDir $FileName
    Write-Host "Running $FileName ..."
    docker cp $path "${Container}:/tmp/$FileName"
    docker exec $Container psql -U $User -d $Database -v ON_ERROR_STOP=1 -f "/tmp/$FileName"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Ensure-Migration015 {
    $mig = Join-Path $Root "db\migrations\015_auto_task_created_at.sql"
    if (Test-Path $mig) {
        Write-Host ">>> patch auto_create_task trigger (015)"
        docker cp $mig "${Container}:/tmp/015_auto_task_created_at.sql"
        docker exec $Container psql -U $User -d $Database -v ON_ERROR_STOP=1 -f /tmp/015_auto_task_created_at.sql
    }
}

function Get-DemoStatus {
    docker exec $Container psql -U $User -d $Database -t -A -c `
        "SELECT CASE WHEN EXISTS (SELECT 1 FROM app_settings WHERE user_id=1 AND key='_demo_dataset') THEN 'loaded' ELSE 'empty' END;"
}

function Show-Summary {
    docker exec $Container psql -U $User -d $Database -c `
        "SELECT value->>'loaded_at' AS loaded_at, jsonb_array_length(value->'tasks') AS tasks, jsonb_array_length(value->'behavior_patterns') AS patterns, jsonb_array_length(value->'diary_entries') AS diary FROM app_settings WHERE user_id=1 AND key='_demo_dataset';"
    docker exec $Container psql -U $User -d $Database -c `
        "SELECT COUNT(*) AS demo_tasks_visible FROM tasks WHERE user_id=1 AND title LIKE '[демо]%';"
}

switch ($Action) {
    "status" {
        if ((Get-DemoStatus) -eq "loaded") { Show-Summary } else { Write-Host "Demo dataset: not loaded." }
    }
    "wipe" {
        Invoke-DemoSql "wipe_demo.sql"
        Write-Host "Demo data removed."
    }
    "seed" {
        Ensure-Migration015
        $state = Get-DemoStatus
        if ($state -eq "loaded") {
            if ($Force) {
                Write-Host "Demo already loaded; -Force: wiping first..."
                Invoke-DemoSql "wipe_demo.sql"
            } else {
                Write-Error "Demo already loaded. Use: demo-data.ps1 wipe  OR  demo-data.ps1 seed -Force"
            }
        }
        Invoke-DemoSql "seed_demo.sql"
        Show-Summary
        Write-Host "Demo data loaded OK."
    }
}
