#Requires -Version 5.1
<#
.SYNOPSIS
  Unattended queue runner: calls Claude Code headless once per task from docs/queue.md
  until nothing is runnable, a task is BLOCKED, or -MaxTasks is reached.
  Each call: claude -p "/goal ..." --permission-mode auto --permission-prompts none
  Tasks with needs: owner / risk-edit are skipped by design (they need a human).
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_queue.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_queue.ps1 -MaxTasks 3 -MaxTurns 40
.NOTES
  Requires Claude Code v2.1.259+ (--permission-prompts). Watch progress with:
  Get-Content data\logs\queue_*.jsonl -Wait -Tail 5
#>
param([int]$MaxTasks = 5, [int]$MaxTurns = 40)
$ErrorActionPreference = 'Stop'
# claude.exe writes UTF-8; without this PowerShell 5.1 decodes it with the OEM code page and Thai text in logs is garbled
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$repo = (Resolve-Path "$PSScriptRoot\..").Path
Set-Location $repo
New-Item -ItemType Directory -Force -Path "$repo\data\logs" | Out-Null

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { throw "claude CLI not found on PATH" }

$goal = "/goal ทำงาน 1 task ตาม .claude/commands/run-task.md และหัวข้อ Queue runner ใน CLAUDE.md (โหมด headless: ข้าม needs owner และ risk-edit). " +
        "จบเมื่อ transcript แสดงบรรทัด QUEUE: T-NNN DONE <hash> พร้อม git push origin main สำเร็จ, " +
        "หรือ QUEUE: T-NNN BLOCKED <เหตุผล> พร้อม push งานที่เสร็จแล้ว, หรือ QUEUE: NOTHING RUNNABLE, หรือครบ $MaxTurns turns. " +
        "ห้ามแก้ค่า risk, ห้าม force push, ห้ามทำเกิน 1 task"

for ($i = 1; $i -le $MaxTasks; $i++) {
    $ready = Select-String -Path "$repo\docs\queue.md" -Pattern '^status:\s*READY' -Quiet
    if (-not $ready) { Write-Host "No READY task in docs/queue.md - stop." -ForegroundColor Yellow; break }

    $before = (git rev-parse HEAD).Trim()
    $stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $log    = "$repo\data\logs\queue_$stamp.jsonl"
    Write-Host "[$i/$MaxTasks] running next task ... log: $log" -ForegroundColor Cyan

    claude -p $goal --permission-mode auto --permission-prompts none --output-format stream-json --verbose |
        Out-File -FilePath $log -Encoding utf8
    $code = $LASTEXITCODE

    $text = Get-Content $log -Raw
    $m = [regex]::Matches($text, 'QUEUE: (T-\d+ (DONE|BLOCKED)[^"\\]*|NOTHING RUNNABLE)')
    $last = if ($m.Count -gt 0) { $m[$m.Count - 1].Groups[1].Value } else { '(no QUEUE line)' }
    Write-Host "  result: $last  (exit $code)"

    if ($code -ne 0)                  { Write-Host "claude exited with $code - stop." -ForegroundColor Red; break }
    if ($last -match 'NOTHING RUNNABLE') {
        if (Get-Process terminal64 -ErrorAction SilentlyContinue) { Write-Host "Hint: MT5 (terminal64) is running - tasks with needs: mt5-closed are skipped. Close MT5 and run again." -ForegroundColor Yellow }
        Write-Host "Nothing runnable - stop and wait for Owner/Cowork." -ForegroundColor Yellow; break
    }
    if ($last -notmatch 'DONE')       { Write-Host "Not DONE - stop and wait for Owner/Cowork." -ForegroundColor Yellow; break }
    if ((git rev-parse HEAD).Trim() -eq $before) { Write-Host "No new commit - stop (no progress)." -ForegroundColor Yellow; break }
}
Write-Host "Queue runner finished. See docs/queue.md and docs/STATUS.md" -ForegroundColor Cyan
