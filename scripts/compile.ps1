#Requires -Version 5.1
<#
.SYNOPSIS
  Compile MQL5 sources through MetaEditor CLI. Exit 0 only if 0 errors AND 0 warnings.
.PARAMETER File
  Path relative to the terminal's MQL5 folder. Default: the EA plus every script in Scripts\SmartEA.
#>
param([string[]]$File)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot\..").Path
$cfg  = Join-Path $PSScriptRoot 'config.local.ps1'
if (-not (Test-Path $cfg)) { throw "Missing $cfg - run scripts/setup.ps1 first" }
. $cfg
$mql5 = Join-Path $MT5_DATA_DIR 'MQL5'

if (-not $File) {
    $File = @()
    $File += Get-ChildItem "$repo\src\Scripts" -Filter *.mq5 -ErrorAction SilentlyContinue |
             ForEach-Object { "Scripts\SmartEA\$($_.Name)" }
    $File += Get-ChildItem "$repo\src\Indicators" -Filter *.mq5 -ErrorAction SilentlyContinue |
             ForEach-Object { "Indicators\SmartEA\$($_.Name)" }
    $File = @($File | Where-Object { $_ -like 'Indicators*' }) + @('Experts\SmartEA\SmartEA.mq5') + @($File | Where-Object { $_ -like 'Scripts*' })
}

function Read-MetaLog([string]$path) {
    # MetaEditor writes UTF-16LE; fall back to UTF-8 if not
    $b = [IO.File]::ReadAllBytes($path)
    if ($b.Length -ge 2 -and ($b[1] -eq 0 -or ($b[0] -eq 0xFF -and $b[1] -eq 0xFE))) {
        return [Text.Encoding]::Unicode.GetString($b).TrimStart([char]0xFEFF)
    }
    return [Text.Encoding]::UTF8.GetString($b)
}

New-Item -ItemType Directory -Force -Path "$repo\data" | Out-Null
$failed = $false
foreach ($f in $File) {
    $target = Join-Path $mql5 $f
    if (-not (Test-Path $target)) { Write-Host "NOT FOUND: $target" -ForegroundColor Red; $failed = $true; continue }
    $name = [IO.Path]::GetFileNameWithoutExtension($f)
    $log  = "$repo\data\compile_$name.log"
    if (Test-Path $log) { Remove-Item $log }
    Start-Process -FilePath $MT5_METAEDITOR -Wait -NoNewWindow `
        -ArgumentList "/compile:`"$target`"", "/log:`"$log`"", "/inc:`"$mql5`""
    if (-not (Test-Path $log)) { Write-Host "No log produced for $f" -ForegroundColor Red; $failed = $true; continue }
    $text = Read-MetaLog $log
    $text -split "`r?`n" | Where-Object { $_ -match 'error|warning|Result' } | ForEach-Object { Write-Host $_ }
    # Anchor on the Result line so "10 errors" never matches "0 errors"
    if ($text -match 'Result:\s*(\d+)\s+errors?,\s*(\d+)\s+warnings?') {
        $e = [int]$Matches[1]; $w = [int]$Matches[2]
        if ($e -eq 0 -and $w -eq 0) { Write-Host "PASS  $f" -ForegroundColor Green }
        else { Write-Host "FAIL  $f  ($e errors, $w warnings)" -ForegroundColor Red; $failed = $true }
    } else { Write-Host "FAIL  $f  (no Result line in log)" -ForegroundColor Red; $failed = $true }
}
if ($failed) { exit 1 } else { exit 0 }
