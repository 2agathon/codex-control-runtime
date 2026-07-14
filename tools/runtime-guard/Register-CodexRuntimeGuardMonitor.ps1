[CmdletBinding()]
param(
    [string] $TaskName = "Codex Runtime Guard Monitor",
    [datetime] $DailyAt = "12:00",
    [string] $InstallDirectory = (Join-Path $env:LOCALAPPDATA "OpenAI\CodexControlRuntimeLab\monitor-bin"),
    [switch] $Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Unregister) {
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Removed scheduled task: $TaskName" -ForegroundColor Green
    }
    else {
        Write-Host "Scheduled task is not installed: $TaskName" -ForegroundColor DarkYellow
    }
    return
}

$sourceMonitor = Join-Path $PSScriptRoot "Invoke-CodexRuntimeGuardMonitor.ps1"
$sourceModule = Join-Path $PSScriptRoot "CodexRuntimeGuard.psm1"
New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
Copy-Item -LiteralPath $sourceMonitor -Destination (Join-Path $InstallDirectory "Invoke-CodexRuntimeGuardMonitor.ps1") -Force
Copy-Item -LiteralPath $sourceModule -Destination (Join-Path $InstallDirectory "CodexRuntimeGuard.psm1") -Force

$monitorScript = Join-Path $InstallDirectory "Invoke-CodexRuntimeGuardMonitor.ps1"
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$arguments = "-NoProfile -NonInteractive -WindowStyle Hidden -File `"$monitorScript`""

$action = New-ScheduledTaskAction -Execute $pwsh -Argument $arguments
$triggers = @(
    (New-ScheduledTaskTrigger -AtLogOn -User $identity),
    (New-ScheduledTaskTrigger -Daily -At $DailyAt)
)
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $triggers `
    -Principal $principal `
    -Settings $settings `
    -Description "Read-only Codex runtime drift detection. Never applies repairs." `
    -Force | Out-Null

Write-Host "Registered scheduled task: $TaskName" -ForegroundColor Green
Write-Host "Monitor files: $InstallDirectory" -ForegroundColor Cyan
Write-Host "Runs at logon and daily at $($DailyAt.ToString('HH:mm')); detection only, no repair." -ForegroundColor Cyan
