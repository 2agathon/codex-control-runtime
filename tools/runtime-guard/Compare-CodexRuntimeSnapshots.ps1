[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Before,
    [Parameter(Mandatory)] [string] $After
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-Snapshot {
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Snapshot not found: $Path"
    }
    $snapshot = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    if ($snapshot.schemaVersion -ne 1) {
        throw "Unsupported snapshot schemaVersion in ${Path}: $($snapshot.schemaVersion)"
    }
    $snapshot
}

function Get-LocalFingerprint {
    param([Parameter(Mandatory)] [object] $Snapshot)

    $localChecks = @(
        $Snapshot.checks |
            Where-Object { $_.layer -notin @("account-workspace", "live-process") } |
            Sort-Object id |
            ForEach-Object { [pscustomobject]@{ id = $_.id; status = $_.status; message = $_.message } }
    )
    $pluginVersions = [ordered]@{}
    foreach ($name in @("browser", "chrome", "computerUse")) {
        $plugin = $Snapshot.state.plugins.$name
        $pluginVersions[$name] = @($plugin.versions)
    }

    $desktopPackages = if ($Snapshot.state.PSObject.Properties.Name -contains "openAIDesktopPackages") {
        @($Snapshot.state.openAIDesktopPackages | ForEach-Object { "$($_.name)@$($_.version)" } | Sort-Object)
    }
    else {
        @()
    }

    [pscustomobject]@{
        appVersion = [string] $Snapshot.state.app.version
        resourcesPath = [string] $Snapshot.state.app.resourcesPath
        openAIDesktopPackages = $desktopPackages
        pluginVersions = [pscustomobject] $pluginVersions
        nativeHostManifest = [string] $Snapshot.state.nativeHost.manifestPath
        nativeHostExecutable = [string] $Snapshot.state.nativeHost.hostPath
        packagedRuntime = [string] $Snapshot.state.cuaRuntime.packagedRuntimeArchiveVersion
        matchingRuntimeIds = @($Snapshot.state.cuaRuntime.matchingRuntimes | Select-Object -ExpandProperty id | Sort-Object)
        chromeProfilesWithExtension = @($Snapshot.state.chromeExtension.profiles | Where-Object installed | Select-Object -ExpandProperty profileDirectory | Sort-Object)
        checks = $localChecks
    }
}

$beforeSnapshot = Read-Snapshot -Path $Before
$afterSnapshot = Read-Snapshot -Path $After
$beforeFingerprint = Get-LocalFingerprint -Snapshot $beforeSnapshot
$afterFingerprint = Get-LocalFingerprint -Snapshot $afterSnapshot

$sameMachine = (
    [string] $beforeSnapshot.context.computerName -eq [string] $afterSnapshot.context.computerName -and
    [string] $beforeSnapshot.context.windowsUserSid -eq [string] $afterSnapshot.context.windowsUserSid
)
$accountChanged = (
    [string] $beforeSnapshot.context.accountLabel -ne [string] $afterSnapshot.context.accountLabel -or
    [string] $beforeSnapshot.context.workspaceLabel -ne [string] $afterSnapshot.context.workspaceLabel
)
$localStateChanged = (
    ($beforeFingerprint | ConvertTo-Json -Depth 20 -Compress) -ne
    ($afterFingerprint | ConvertTo-Json -Depth 20 -Compress)
)

$beforeChecks = @{}
foreach ($check in $beforeSnapshot.checks) { $beforeChecks[[string] $check.id] = $check }
$afterChecks = @{}
foreach ($check in $afterSnapshot.checks) { $afterChecks[[string] $check.id] = $check }

$checkChanges = @()
foreach ($id in @($beforeChecks.Keys + $afterChecks.Keys | Sort-Object -Unique)) {
    $beforeStatus = if ($beforeChecks.ContainsKey($id)) { [string] $beforeChecks[$id].status } else { "MISSING" }
    $afterStatus = if ($afterChecks.ContainsKey($id)) { [string] $afterChecks[$id].status } else { "MISSING" }
    if ($beforeStatus -ne $afterStatus) {
        $checkChanges += [pscustomobject]@{ id = $id; before = $beforeStatus; after = $afterStatus }
    }
}

$classification = if (-not $sameMachine) {
    "NEW_LOCAL_CONTEXT"
}
elseif ($localStateChanged) {
    "LOCAL_STATE_CHANGED"
}
elseif ($accountChanged) {
    "ACCOUNT_CHANGED_LOCAL_STABLE"
}
else {
    "NO_RELEVANT_CHANGE"
}

[pscustomobject]@{
    classification = $classification
    sameMachineAndWindowsUser = $sameMachine
    accountOrWorkspaceLabelChanged = $accountChanged
    localStateChanged = $localStateChanged
    before = [pscustomobject]@{
        generatedAt = $beforeSnapshot.generatedAt
        accountLabel = $beforeSnapshot.context.accountLabel
        workspaceLabel = $beforeSnapshot.context.workspaceLabel
        overall = $beforeSnapshot.overall
    }
    after = [pscustomobject]@{
        generatedAt = $afterSnapshot.generatedAt
        accountLabel = $afterSnapshot.context.accountLabel
        workspaceLabel = $afterSnapshot.context.workspaceLabel
        overall = $afterSnapshot.overall
    }
    changedChecks = $checkChanges
} | Format-List

if ($checkChanges.Count -gt 0) {
    $checkChanges | Format-Table id, before, after -AutoSize
}

switch ($classification) {
    "NEW_LOCAL_CONTEXT" {
        Write-Host "Treat this as a new device/Windows-user bootstrap. Do not attribute differences to the ChatGPT account alone." -ForegroundColor Yellow
    }
    "LOCAL_STATE_CHANGED" {
        Write-Host "A local layer changed. Diagnose the changed check before investigating account entitlement." -ForegroundColor Yellow
    }
    "ACCOUNT_CHANGED_LOCAL_STABLE" {
        Write-Host "Local state is stable across the account/workspace switch. If strict acceptance differs, investigate plan, rollout, workspace policy, or task routing before local repair." -ForegroundColor Cyan
    }
    default {
        Write-Host "No relevant local or labeled account/workspace change was detected." -ForegroundColor Green
    }
}
