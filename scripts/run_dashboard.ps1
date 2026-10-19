<#
.SYNOPSIS
  สร้าง dashboard (scripts/dashboard.py) วนทุก 30 วินาที และเปิด browser ครั้งแรก — กด Ctrl+C เพื่อหยุด
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_dashboard.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_dashboard.ps1 -IntervalSec 10 -NoBrowser
#>
param(
    [int]$IntervalSec = 30,
    [switch]$NoBrowser
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$py   = Join-Path $root 'scripts\dashboard.py'
$out  = Join-Path $root 'data\dashboard\index.html'

if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw 'ไม่พบ python ใน PATH' }

$opened = $false
while ($true) {
    & python $py
    if ($LASTEXITCODE -ne 0) { Write-Warning "dashboard.py exit $LASTEXITCODE (จะลองใหม่รอบหน้า)" }
    elseif (-not $opened -and -not $NoBrowser) { Start-Process $out; $opened = $true }
    Start-Sleep -Seconds $IntervalSec
}
