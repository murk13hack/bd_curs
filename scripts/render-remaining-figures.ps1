# Рисунки 9–14 (кроме скриншота 10): без Fedora/npm
#   pip install pillow
#   .\scripts\render-remaining-figures.ps1

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

python scripts/render_diagrams_pil.py
python scripts/render_explain_png.py
Write-Host "PNG: docs/diagrams/png/09, 11-14"
