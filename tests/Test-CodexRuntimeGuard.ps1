[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$modulePath = Join-Path $PSScriptRoot "..\tools\runtime-guard\CodexRuntimeGuard.psm1"
Import-Module $modulePath -Force
$reportSchemaPath = Join-Path $PSScriptRoot "..\schemas\runtime-guard-report.schema.json"

function Assert-Guard {
    param(
        [Parameter(Mandatory)] [bool] $Condition,
        [Parameter(Mandatory)] [string] $Message
    )
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

$module = Get-Module CodexRuntimeGuard
$missingPluginState = & $module {
    Get-PluginState -Name "fixture-plugin-that-does-not-exist" -RequiredFiles @("missing.txt")
}
Assert-Guard (-not $missingPluginState.rootExists) "missing plugin root must be reported without throwing"
Assert-Guard (@($missingPluginState.versions).Count -eq 0) "missing plugin must report an empty version list"

$codexPackage = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue
if ($codexPackage) {
    $report = Get-CodexRuntimeGuardReport
    Assert-Guard ($report.schemaVersion -eq 1) "diagnosis schemaVersion"
    Assert-Guard (@($report.checks).Count -ge 10) "expected diagnostic layers"
    Assert-Guard (@($report.checks.id | Sort-Object -Unique).Count -eq @($report.checks).Count) "check IDs must be unique"
    Assert-Guard ($report.acceptanceRequired -eq $true) "acceptance must remain explicit"
    Assert-Guard (($report | ConvertTo-Json -Depth 40) | Test-Json -SchemaFile $reportSchemaPath) "live diagnosis must match report schema"

    $dryRun = Invoke-CodexRuntimeGuardRepair
    Assert-Guard (-not $dryRun.applied) "repair defaults to dry run"
    Assert-Guard (@($dryRun.actions | Where-Object status -eq "APPLIED").Count -eq 0) "dry run must not apply actions"
}
else {
    Write-Host "Codex AppX is not installed; skipping live-host integration assertions."
}

$fixtureRoot = Join-Path $env:TEMP "codex-runtime-guard-test-$PID"
try {
    $currentResources = Join-Path $fixtureRoot "current-resources"
    $backupRoot = Join-Path $fixtureRoot "backups"
    New-Item -ItemType Directory -Path $currentResources -Force | Out-Null

    $manifestPaths = @(
        (Join-Path $fixtureRoot "stale-v2.json"),
        (Join-Path $fixtureRoot "missing-property-v2.json")
    )
    $staleFixture = [pscustomobject]@{
        schemaVersion = 2
        entries = @(
            [pscustomobject]@{
                nativeHostNames = @("com.openai.codexextension")
                paths = [pscustomobject]@{ resourcesPath = "C:\missing-old-resources" }
            }
        )
    }
    $missingPropertyFixture = [pscustomobject]@{
        schemaVersion = 2
        entries = @(
            [pscustomobject]@{
                nativeHostNames = @("com.openai.codexextension")
                paths = [pscustomobject]@{ codexHome = "C:\fixture-codex-home" }
            }
        )
    }
    $staleFixture | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPaths[0] -Encoding utf8
    $missingPropertyFixture | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPaths[1] -Encoding utf8

    $app = [pscustomobject]@{ resourcesPath = $currentResources }
    $dryActions = @(& $module { param($appArg, $pathsArg, $backupArg) Repair-ResourcePaths -App $appArg -ManifestPaths $pathsArg -BackupDirectory $backupArg } $app $manifestPaths $backupRoot)
    Assert-Guard (@($dryActions | Where-Object status -eq "DRY_RUN").Count -eq 2) "resource-path fixture dry run"
    $staleAfterDryRun = Get-Content -Raw -LiteralPath $manifestPaths[0] | ConvertFrom-Json
    $missingAfterDryRun = Get-Content -Raw -LiteralPath $manifestPaths[1] | ConvertFrom-Json
    Assert-Guard ($staleAfterDryRun.entries[0].paths.resourcesPath -eq "C:\missing-old-resources") "dry run must preserve stale fixture"
    Assert-Guard (-not ($missingAfterDryRun.entries[0].paths.PSObject.Properties.Name -contains "resourcesPath")) "dry run must not add a missing property"

    $applyActions = @(& $module { param($appArg, $pathsArg, $backupArg) Repair-ResourcePaths -App $appArg -ManifestPaths $pathsArg -BackupDirectory $backupArg -Apply } $app $manifestPaths $backupRoot)
    Assert-Guard (@($applyActions | Where-Object status -eq "APPLIED").Count -eq 2) "resource-path fixture apply"
    foreach ($path in $manifestPaths) {
        $value = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
        Assert-Guard ($value.entries[0].paths.resourcesPath -eq $currentResources) "fixture must point to current resources"
    }
    Assert-Guard (@(Get-ChildItem -LiteralPath $backupRoot -File).Count -eq 2) "fixture backups"
}
finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$runtimeFixtureRoot = Join-Path $env:TEMP "codex-runtime-guard-cua-test-$PID"
try {
    $packagedRuntime = Join-Path $runtimeFixtureRoot "packaged-cua-node"
    $relocatedRoot = Join-Path $runtimeFixtureRoot "relocated"
    $incompleteRuntime = Join-Path $runtimeFixtureRoot "incomplete-cua-node"
    New-Item -ItemType Directory -Path $incompleteRuntime -Force | Out-Null
    [pscustomobject]@{ runtime_archive_version = "0.0.98/incomplete" } |
        ConvertTo-Json |
        Set-Content -LiteralPath (Join-Path $incompleteRuntime "manifest.json") -Encoding utf8
    $incompleteState = & $module { param($sourceArg) Get-CuaRuntimeState -PackagedCuaNodePath $sourceArg } $incompleteRuntime
    Assert-Guard ($null -eq $incompleteState.expectedRuntimeId) "incomplete CUA runtime has no content ID"
    Assert-Guard ([bool] $incompleteState.expectedRuntimeIdError) "incomplete CUA runtime preserves the fingerprint error"

    $helperPath = Join-Path $packagedRuntime "bin\node_modules\@oai\sky\bin\windows\codex-computer-use.exe"
    New-Item -ItemType Directory -Path (Split-Path $helperPath -Parent) -Force | Out-Null
    [pscustomobject]@{
        runtime_archive_version = "0.0.99/fixture"
        node_path = "bin/node.exe"
        node_repl_path = "bin/node_repl.exe"
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packagedRuntime "manifest.json") -Encoding utf8
    [IO.File]::WriteAllBytes((Join-Path $packagedRuntime "bin\node.exe"), [byte[]](1, 2, 3, 4))
    [IO.File]::WriteAllBytes((Join-Path $packagedRuntime "bin\node_repl.exe"), [byte[]](5, 6, 7, 8))
    [IO.File]::WriteAllBytes($helperPath, [byte[]](9, 10, 11, 12))

    $runtimeState = [pscustomobject]@{
        packagedPath = $packagedRuntime
        packagedPathExists = $true
        packagedManifestValid = $true
        runtimeRoot = $relocatedRoot
        matchingRuntimes = @()
    }
    $expectedRuntimeId = & $module { param($sourceArg) Get-CuaRuntimeId -SourcePath $sourceArg } $packagedRuntime
    Assert-Guard ($expectedRuntimeId -match '^[0-9a-f]{16}$') "CUA runtime ID shape"

    $runtimeDryRun = & $module { param($stateArg) Repair-CuaRuntime -RuntimeState $stateArg } $runtimeState
    Assert-Guard ($runtimeDryRun.status -eq "DRY_RUN") "CUA runtime repair defaults to dry run"
    Assert-Guard (-not (Test-Path -LiteralPath $runtimeDryRun.path)) "CUA runtime dry run must not create destination"

    $runtimeApply = & $module { param($stateArg) Repair-CuaRuntime -RuntimeState $stateArg -Apply } $runtimeState
    Assert-Guard ($runtimeApply.status -eq "APPLIED") "CUA runtime fixture apply"
    Assert-Guard ($runtimeApply.runtimeId -eq $expectedRuntimeId) "CUA runtime fixture uses official content ID"
    Assert-Guard ((Get-FileHash -LiteralPath (Join-Path $packagedRuntime "bin\node.exe")).Hash -eq (Get-FileHash -LiteralPath (Join-Path $runtimeApply.path "bin\node.exe")).Hash) "CUA runtime node hash"
    Assert-Guard ((Get-FileHash -LiteralPath (Join-Path $packagedRuntime "bin\node_repl.exe")).Hash -eq (Get-FileHash -LiteralPath (Join-Path $runtimeApply.path "bin\node_repl.exe")).Hash) "CUA runtime node_repl hash"

    $runtimeState.matchingRuntimes = @([pscustomobject]@{
        manifestValid = $true
        nodeExists = $true
        nodeReplExists = $true
        computerUseHelperExists = $true
        path = $runtimeApply.path
    })
    $runtimeNoop = & $module { param($stateArg) Repair-CuaRuntime -RuntimeState $stateArg -Apply } $runtimeState
    Assert-Guard ($runtimeNoop.status -eq "NOOP") "healthy CUA runtime must not be rewritten"
}
finally {
    Remove-Item -LiteralPath $runtimeFixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$redactionRoot = Join-Path $env:TEMP "codex-runtime-guard-redaction-test-$PID"
try {
    New-Item -ItemType Directory -Path $redactionRoot -Force | Out-Null
    $rawSnapshotPath = Join-Path $redactionRoot "raw.json"
    $publicSnapshotPath = Join-Path $redactionRoot "public.json"
    [pscustomobject]@{
        context = [pscustomobject]@{
            machineName = $env:COMPUTERNAME
            windowsUser = $env:USERNAME
            windowsUserSid = "S-1-5-21-111-222-333-444"
            accountLabel = "private-account"
        }
        details = [pscustomobject]@{
            path = Join-Path $env:USERPROFILE ".codex\plugins"
            profilePath = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Profile 7"
            token = "do-not-publish"
            version = "26.707.31428"
            checks = @([pscustomobject]@{ id = "app.codex"; status = "PASS" })
            emptyChecks = @()
        }
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $rawSnapshotPath -Encoding utf8

    $exportScript = Join-Path $PSScriptRoot "..\tools\runtime-guard\Export-CodexRuntimeGuardSnapshot.ps1"
    & $exportScript -InputPath $rawSnapshotPath -OutputPath $publicSnapshotPath
    $publicText = Get-Content -Raw -LiteralPath $publicSnapshotPath
    $publicValue = $publicText | ConvertFrom-Json

    Assert-Guard ($publicValue.context.machineName -eq "REDACTED") "machine name property redaction"
    Assert-Guard ($publicValue.context.windowsUserSid -eq "REDACTED") "SID property redaction"
    Assert-Guard ($publicValue.details.token -eq "REDACTED") "token property redaction"
    Assert-Guard ($publicText -notmatch [regex]::Escape($env:USERPROFILE)) "user profile path redaction"
    Assert-Guard ($publicText -notmatch "Profile 7") "Chrome profile name redaction"
    Assert-Guard ($publicValue.details.version -eq "26.707.31428") "version must remain available"
    Assert-Guard (@($publicValue.details.checks).Count -eq 1) "single-element arrays must remain arrays"
    Assert-Guard (@($publicValue.details.emptyChecks).Count -eq 0) "empty arrays must remain arrays"
}
finally {
    Remove-Item -LiteralPath $redactionRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$exampleSnapshotPath = Join-Path $PSScriptRoot "..\fixtures\redacted-snapshot.example.json"
Assert-Guard ((Get-Content -Raw -LiteralPath $exampleSnapshotPath) | Test-Json -SchemaFile $reportSchemaPath) "redacted example must match report schema"

$monitorRoot = Join-Path $env:TEMP "codex-runtime-guard-monitor-test-$PID"
try {
    $monitorScript = Join-Path $PSScriptRoot "..\tools\runtime-guard\Invoke-CodexRuntimeGuardMonitor.ps1"
    $firstMonitorRun = & $monitorScript -StateDirectory $monitorRoot -NoNotification -PassThru
    $secondMonitorRun = & $monitorScript -StateDirectory $monitorRoot -NoNotification -PassThru
    Assert-Guard ($firstMonitorRun.event -eq "BASELINE") "first monitor run must establish a baseline"
    Assert-Guard ($secondMonitorRun.event -eq "UNCHANGED") "second monitor run must remain quiet when state is stable"
    $monitorStatePath = Join-Path $monitorRoot "monitor-state.json"
    Assert-Guard (Test-Path -LiteralPath $monitorStatePath) "monitor state must be persisted"
    $forcedDriftState = Get-Content -Raw -LiteralPath $monitorStatePath | ConvertFrom-Json
    $forcedDriftState.runtimeFingerprint = "forced-test-drift"
    $forcedDriftState | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $monitorStatePath -Encoding utf8
    $thirdMonitorRun = & $monitorScript -StateDirectory $monitorRoot -NoNotification -PassThru
    Assert-Guard ($thirdMonitorRun.event -eq "RUNTIME_FINGERPRINT_CHANGED") "plugin/runtime fingerprint drift must be detected"
}
finally {
    Remove-Item -LiteralPath $monitorRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if ($codexPackage -and (Get-CodexRuntimeGuardReport).overall -eq "PASS") {
    $autoHealRoot = Join-Path $env:TEMP "codex-runtime-guard-auto-heal-test-$PID"
    try {
        $autoHealScript = Join-Path $PSScriptRoot "..\tools\runtime-guard\Invoke-CodexRuntimeGuardAutoHeal.ps1"
        $autoHealResult = & $autoHealScript -StateDirectory $autoHealRoot -NoNotification -NoProcessRefresh -PassThru
        Assert-Guard ($autoHealResult.event -eq "HEALTHY") "healthy auto-heal run must remain a no-op"
        Assert-Guard (@($autoHealResult.actions).Count -eq 0) "healthy auto-heal run must not apply actions"
    }
    finally {
        Remove-Item -LiteralPath $autoHealRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Codex Runtime Guard self-test passed." -ForegroundColor Green
