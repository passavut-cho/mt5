#Requires -Version 5.1
<#
.SYNOPSIS
  Run a headless Strategy Tester pass from tests/tester-ini/<Ini>.ini and collect the
  report into data/reports/. The MT5 terminal for this data folder must be CLOSED first.
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_backtest.ps1 -Ini smoke
#>
param([Parameter(Mandatory)][string]$Ini, [int]$TimeoutMin = 90)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot\..").Path
. (Join-Path $PSScriptRoot 'config.local.ps1')

$iniSrc = "$repo\tests\tester-ini\$Ini.ini"
if (-not (Test-Path $iniSrc)) { throw "Not found: $iniSrc" }
$lines = Get-Content $iniSrc

function Get-IniValue($key) {
    foreach ($l in $lines) { if ($l -match "^\s*$key\s*=\s*(.+?)\s*$") { return $Matches[1] } }
    return $null
}

# .set must live in MQL5\Profiles\Tester
$set = Get-IniValue 'ExpertParameters'
if ($set) {
    $setSrc = "$repo\tests\setfiles\$set"
    if (-not (Test-Path $setSrc)) { throw "Set file not found: $setSrc" }
    $setDst = Join-Path $MT5_DATA_DIR "MQL5\Profiles\Tester"
    New-Item -ItemType Directory -Force -Path $setDst | Out-Null
    Copy-Item $setSrc $setDst -Force
}

$report = Get-IniValue 'Report'
if (-not $report) { throw "Ini must define Report=reports\<name>" }
if ((Get-IniValue 'ShutdownTerminal') -ne '1') { throw "Ini must set ShutdownTerminal=1 or this script will hang" }

$running = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $MT5_TERMINAL }
if ($running) { throw "MT5 terminal is running - close it first (tester needs exclusive access to this data folder)" }

$reportDir = Join-Path $MT5_DATA_DIR (Split-Path $report -Parent)
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$leaf = Split-Path $report -Leaf
Get-ChildItem $reportDir -Filter "$leaf*" -ErrorAction SilentlyContinue | Remove-Item -Force

$tmpIni = Join-Path $env:TEMP "smartea_$Ini.ini"
$lines | Set-Content $tmpIni -Encoding ASCII

Write-Host "Running tester: $Ini ..." -ForegroundColor Cyan
$p = Start-Process -FilePath $MT5_TERMINAL -ArgumentList "/config:`"$tmpIni`"" -PassThru
if (-not $p.WaitForExit($TimeoutMin * 60 * 1000)) { $p.Kill(); throw "Tester timed out after $TimeoutMin min" }

$out = "$repo\data\reports"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$files = Get-ChildItem $reportDir -Filter "$leaf*"
if (-not $files) { throw "No report produced. Check the tester journal in $MT5_DATA_DIR\Tester\logs" }
$files | Copy-Item -Destination $out -Force
$files | ForEach-Object { Write-Host "Report: $out\$($_.Name)" -ForegroundColor Green }
