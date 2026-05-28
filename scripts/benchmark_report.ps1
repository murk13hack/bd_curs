# Windows-обёртка (основной запуск — benchmark_report.sh в Git Bash / WSL).
# Использование (из корня репозитория):
#   .\scripts\benchmark_report.ps1
#   .\scripts\benchmark_report.ps1 -Count 10000
#   .\scripts\benchmark_report.ps1 -SkipLoad

param(
    [int]$Count = 10000,
    [switch]$SkipLoad,
    [switch]$NoDiarySeed,
    [switch]$SkipQ2Compare,
    [string]$Container = "ptt-db"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    $py = Get-Command py -ErrorAction SilentlyContinue
}
if (-not $py) {
    Write-Error "Python не найден. Установите Python 3.12+ или запустите: python scripts/benchmark_report.py"
}

$args = @("scripts/benchmark_report.py", "--count", $Count, "--container", $Container)
if ($SkipLoad) { $args += "--skip-load" }
if ($NoDiarySeed) { $args += "--no-diary-seed" }
if ($SkipQ2Compare) { $args += "--skip-q2-compare" }

& $py.Source @args
exit $LASTEXITCODE
