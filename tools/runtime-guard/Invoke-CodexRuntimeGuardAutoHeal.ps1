[CmdletBinding()]
param(
    [string] $StateDirectory = (Join-Path $env:LOCALAPPDATA "OpenAI\CodexControlRuntimeLab\auto-heal"),
    [switch] $NoNotification,
    [switch] $NoProcessRefresh,
    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "CodexRuntimeGuard.psm1") -Force

function Show-AutoHealNotification {
    param(
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $Message
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $notification = [System.Windows.Forms.NotifyIcon]::new()
        try {
            $notification.Icon = [System.Drawing.SystemIcons]::Information
            $notification.Visible = $true
            $notification.BalloonTipTitle = $Title
            $notification.BalloonTipText = $Message
            $notification.ShowBalloonTip(10000)
            Start-Sleep -Seconds 8
        }
        finally {
            $notification.Dispose()
        }
    }
    catch {
        Write-Warning "Unable to display the Runtime Guard notification: $($_.Exception.Message)"
    }
}

function Stop-CurrentChromeExtensionHost {
    param([Parameter(Mandatory)] [object] $Report)

    $activePath = [string] $Report.state.plugins.chrome.activePath
    if (-not $activePath) {
        return 0
    }
    $expectedPath = Join-Path $activePath "extension-host\windows\x64\extension-host.exe"
    if (-not (Test-Path -LiteralPath $expectedPath)) {
        return 0
    }

    $normalizedExpected = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $expectedPath).Path)
    $hosts = @(Get-CimInstance Win32_Process -Filter "Name='extension-host.exe'" | Where-Object {
        $_.ExecutablePath -and
        [IO.Path]::GetFullPath($_.ExecutablePath) -eq $normalizedExpected
    })
    foreach ($hostProcess in $hosts) {
        Stop-Process -Id $hostProcess.ProcessId -Force
    }
    $hosts.Count
}

function Get-RepairTargets {
    param([Parameter(Mandatory)] [object] $Report)

    $targets = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($check in @($Report.checks | Where-Object { $_.status -eq "FAIL" -and $_.repairable })) {
        switch -Regex ($check.id) {
            '^plugin\.chrome$' { [void] $targets.Add("ChromeLatest") }
            '^chrome\.native-host$' { [void] $targets.Add("NativeHost") }
            '^chrome\.v2-manifest\.' { [void] $targets.Add("ResourcePaths") }
            '^computer-use\.runtime$' { [void] $targets.Add("CuaRuntime") }
        }
    }
    @($targets)
}

New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
$latestPath = Join-Path $StateDirectory "latest.json"
$previousResult = $null
if (Test-Path -LiteralPath $latestPath) {
    try {
        $previousResult = Get-Content -Raw -LiteralPath $latestPath | ConvertFrom-Json
    }
    catch {
        Write-Warning "Ignoring invalid previous Auto-Heal state: $latestPath"
    }
}
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$identityHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($identity))).Substring(0, 12)
$mutex = [Threading.Mutex]::new($false, "Local\CodexRuntimeGuardAutoHeal-$identityHash")
$lockAcquired = $false

try {
    $lockAcquired = $mutex.WaitOne(0)
    if (-not $lockAcquired) {
        $result = [pscustomobject]@{
            schemaVersion = 1
            checkedAt = (Get-Date).ToString("o")
            event = "SKIPPED_CONCURRENT_RUN"
            targets = @()
            actions = @()
            overall = $null
            extensionHostsStopped = 0
            codexRestartRequired = $false
        }
    }
    else {
        $before = Get-CodexRuntimeGuardReport
        $targets = @(Get-RepairTargets -Report $before)
        $repair = $null
        $after = $before
        if ($targets.Count -gt 0) {
            $repair = Invoke-CodexRuntimeGuardRepair -Target $targets -Apply
            $after = $repair.after
        }

        $actions = if ($repair) { @($repair.actions) } else { @() }
        $applied = @($actions | Where-Object status -eq "APPLIED")
        $chromeChanged = @($applied | Where-Object target -in @("resourcesPath", "chromeLatest", "nativeHost")).Count -gt 0
        $cuaChanged = @($applied | Where-Object target -eq "cuaRuntime").Count -gt 0
        $extensionHostsStopped = if ($chromeChanged -and -not $NoProcessRefresh) {
            Stop-CurrentChromeExtensionHost -Report $after
        }
        else {
            0
        }
        $codexRestartRequired = $cuaChanged -and @(Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue).Count -gt 0

        $event = if ($after.overall -eq "PASS" -and $applied.Count -gt 0) {
            "REPAIRED"
        }
        elseif ($after.overall -eq "PASS") {
            "HEALTHY"
        }
        elseif ($applied.Count -gt 0) {
            "REPAIR_INCOMPLETE"
        }
        else {
            "UNREPAIRED_FAILURE"
        }

        $result = [pscustomobject]@{
            schemaVersion = 1
            checkedAt = (Get-Date).ToString("o")
            event = $event
            targets = @($targets)
            actions = @($actions)
            overall = [string] $after.overall
            extensionHostsStopped = $extensionHostsStopped
            codexRestartRequired = [bool] $codexRestartRequired
        }
    }

    $result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $latestPath -Encoding utf8
    ($result | ConvertTo-Json -Depth 20 -Compress) | Add-Content -LiteralPath (Join-Path $StateDirectory "history.jsonl") -Encoding utf8

    if (-not $NoNotification) {
        if ($result.event -eq "REPAIRED") {
            $message = if ($result.codexRestartRequired) {
                "Local runtime drift was repaired. Reopen Codex once before using Computer Use."
            }
            else {
                "Local runtime drift was repaired automatically."
            }
            Show-AutoHealNotification -Title "Codex Runtime Guard" -Message $message
        }
        elseif (
            $result.event -in @("REPAIR_INCOMPLETE", "UNREPAIRED_FAILURE") -and
            (
                -not $previousResult -or
                [string] $previousResult.event -ne [string] $result.event -or
                [string] $previousResult.overall -ne [string] $result.overall
            )
        ) {
            Show-AutoHealNotification -Title "Codex Runtime Guard needs attention" -Message "An unknown or non-repairable local failure remains. Open the latest auto-heal report for the exact failed gate."
        }
    }

    if ($PassThru) {
        $result
    }
}
finally {
    if ($lockAcquired) {
        [void] $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
}
