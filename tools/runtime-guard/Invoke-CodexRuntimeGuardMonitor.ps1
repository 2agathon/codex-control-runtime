[CmdletBinding()]
param(
    [string] $StateDirectory = (Join-Path $env:LOCALAPPDATA "OpenAI\CodexControlRuntimeLab\monitor"),
    [switch] $Deep,
    [switch] $NoNotification,
    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "CodexRuntimeGuard.psm1") -Force

function Show-GuardNotification {
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

function Get-RuntimeFingerprint {
    param([Parameter(Mandatory)] [object] $Report)

    $fingerprintSource = if ($Report.state) {
        [ordered]@{
            appVersion = [string] $Report.state.app.version
            plugins = [ordered]@{
                browser = @($Report.state.plugins.browser.versions)
                chrome = @($Report.state.plugins.chrome.versions)
                computerUse = @($Report.state.plugins.computerUse.versions)
            }
            packagedCuaRuntime = [string] $Report.state.cuaRuntime.packagedRuntimeArchiveVersion
        }
    }
    else {
        [ordered]@{ appVersion = "not-installed" }
    }

    $json = $fingerprintSource | ConvertTo-Json -Depth 10 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
$statePath = Join-Path $StateDirectory "monitor-state.json"
$previous = $null
if (Test-Path -LiteralPath $statePath) {
    try {
        $previous = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
    }
    catch {
        Write-Warning "Ignoring invalid monitor state: $statePath"
    }
}
if ($previous) {
    $requiredStateProperties = @("appVersion", "runtimeFingerprint", "overall")
    $missingStateProperties = @($requiredStateProperties | Where-Object { -not ($previous.PSObject.Properties.Name -contains $_) })
    if ($missingStateProperties.Count -gt 0) {
        Write-Warning "Monitor state uses an older or incomplete schema; establishing a new baseline."
        $previous = $null
    }
}

$report = Get-CodexRuntimeGuardReport -Deep:$Deep
$appVersion = if ($report.state -and $report.state.app) {
    [string] $report.state.app.version
}
else {
    "not-installed"
}
$runtimeFingerprint = Get-RuntimeFingerprint -Report $report

$event = if (-not $previous) {
    "BASELINE"
}
elseif ([string] $previous.appVersion -ne $appVersion) {
    "APP_VERSION_CHANGED"
}
elseif ([string] $previous.runtimeFingerprint -ne $runtimeFingerprint) {
    "RUNTIME_FINGERPRINT_CHANGED"
}
elseif ([string] $previous.overall -ne [string] $report.overall) {
    "LOCAL_STATUS_CHANGED"
}
else {
    "UNCHANGED"
}

$checkedAt = (Get-Date).ToString("o")
$snapshotPath = $null
if ($event -ne "UNCHANGED") {
    $snapshotDirectory = Join-Path $StateDirectory "snapshots"
    New-Item -ItemType Directory -Path $snapshotDirectory -Force | Out-Null
    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $snapshotPath = Join-Path $snapshotDirectory "$stamp-$($event.ToLowerInvariant()).json"
    $report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $snapshotPath -Encoding utf8
}

[pscustomobject]@{
    schemaVersion = 1
    checkedAt = $checkedAt
    appVersion = $appVersion
    runtimeFingerprint = $runtimeFingerprint
    overall = [string] $report.overall
    event = $event
    snapshotPath = $snapshotPath
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding utf8

if (-not $NoNotification -and $event -ne "UNCHANGED") {
    $message = switch ($event) {
        "BASELINE" { "Baseline saved for Codex $appVersion. Local status: $($report.overall)." }
        "APP_VERSION_CHANGED" { "Codex changed to $appVersion. Local status: $($report.overall). Run strict acceptance before relying on control tools." }
        "RUNTIME_FINGERPRINT_CHANGED" { "A bundled plugin or runtime changed. Local status: $($report.overall). Run strict acceptance before relying on control tools." }
        "LOCAL_STATUS_CHANGED" { "Local runtime status changed to $($report.overall). No repair was applied." }
    }
    Show-GuardNotification -Title "Codex Runtime Guard" -Message $message
}

if ($PassThru) {
    [pscustomobject]@{
        event = $event
        appVersion = $appVersion
        runtimeFingerprint = $runtimeFingerprint
        overall = [string] $report.overall
        statePath = $statePath
        snapshotPath = $snapshotPath
    }
}
