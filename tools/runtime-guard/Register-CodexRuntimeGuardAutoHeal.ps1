[CmdletBinding()]
param(
    [string] $TaskName = "Codex Runtime Guard Auto-Heal",
    [string] $RunValueName = "CodexRuntimeGuardAutoHeal",
    [timespan] $Interval = (New-TimeSpan -Minutes 10),
    [string] $InstallDirectory = (Join-Path $env:LOCALAPPDATA "OpenAI\CodexControlRuntimeLab\auto-heal-bin"),
    [switch] $Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

if ($Unregister) {
    try {
        $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Host "Removed scheduled task: $TaskName" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Unable to inspect or remove scheduled task '$TaskName': $($_.Exception.Message)"
    }
    $runEntry = Get-ItemProperty -LiteralPath $runKey -Name $RunValueName -ErrorAction SilentlyContinue
    if ($runEntry -and $runEntry.PSObject.Properties.Name -contains $RunValueName) {
        Remove-ItemProperty -LiteralPath $runKey -Name $RunValueName -Force
        Write-Host "Removed current-user startup entry: $RunValueName" -ForegroundColor Green
    }
    return
}

if ($Interval -lt (New-TimeSpan -Minutes 5)) {
    throw "Interval must be at least five minutes."
}

$sourceAutoHeal = Join-Path $PSScriptRoot "Invoke-CodexRuntimeGuardAutoHeal.ps1"
$sourceModule = Join-Path $PSScriptRoot "CodexRuntimeGuard.psm1"
$sourceDaemon = Join-Path $PSScriptRoot "Start-CodexRuntimeGuardAutoHealDaemon.ps1"
New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
Copy-Item -LiteralPath $sourceAutoHeal -Destination (Join-Path $InstallDirectory "Invoke-CodexRuntimeGuardAutoHeal.ps1") -Force
Copy-Item -LiteralPath $sourceModule -Destination (Join-Path $InstallDirectory "CodexRuntimeGuard.psm1") -Force
Copy-Item -LiteralPath $sourceDaemon -Destination (Join-Path $InstallDirectory "Start-CodexRuntimeGuardAutoHealDaemon.ps1") -Force

$autoHealScript = Join-Path $InstallDirectory "Invoke-CodexRuntimeGuardAutoHeal.ps1"
$daemonScript = Join-Path $InstallDirectory "Start-CodexRuntimeGuardAutoHealDaemon.ps1"
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$arguments = "-NoProfile -NonInteractive -WindowStyle Hidden -File `"$autoHealScript`""

$action = New-ScheduledTaskAction -Execute $pwsh -Argument $arguments
$triggers = @(
    (New-ScheduledTaskTrigger -AtLogOn -User $identity),
    (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval $Interval -RepetitionDuration (New-TimeSpan -Days 3650))
)
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

try {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $triggers `
        -Principal $principal `
        -Settings $settings `
        -Description "Allowlisted Codex runtime self-healing with backups, verification, and no forced Codex restart." `
        -Force `
        -ErrorAction Stop | Out-Null

    Remove-ItemProperty -LiteralPath $runKey -Name $RunValueName -Force -ErrorAction SilentlyContinue
    Write-Host "Registered scheduled task: $TaskName" -ForegroundColor Green
    Write-Host "Runs at logon and every $([int] $Interval.TotalMinutes) minute(s)." -ForegroundColor Cyan
}
catch {
    $daemonArguments = "-NoProfile -NonInteractive -WindowStyle Hidden -File `"$daemonScript`" -Interval `"$Interval`""
    $daemonCommand = "`"$pwsh`" $daemonArguments"
    $launcherPath = Join-Path $InstallDirectory "Start-CodexRuntimeGuardAutoHealHidden.vbs"
    $escapedDaemonCommand = $daemonCommand.Replace('"', '""')
    @"
Set shell = CreateObject("WScript.Shell")
shell.Run "$escapedDaemonCommand", 0, False
"@ | Set-Content -LiteralPath $launcherPath -Encoding ascii

    $wscript = Join-Path $env:WINDIR "System32\wscript.exe"
    $runCommand = "`"$wscript`" `"$launcherPath`""
    New-Item -Path $runKey -Force | Out-Null
    Set-ItemProperty -LiteralPath $runKey -Name $RunValueName -Value $runCommand -Type String
    Write-Warning "Scheduled-task registration was unavailable: $($_.Exception.Message)"
    Write-Host "Registered current-user startup daemon instead: $RunValueName" -ForegroundColor Green
    Write-Host "Runs at logon and every $([int] $Interval.TotalMinutes) minute(s) while the user session is active." -ForegroundColor Cyan
}

Write-Host "Auto-heal files: $InstallDirectory" -ForegroundColor Cyan
