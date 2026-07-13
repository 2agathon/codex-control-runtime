[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$modulePath = Join-Path $PSScriptRoot "..\tools\runtime-guard\CodexRuntimeGuard.psm1"
Import-Module $modulePath -Force

function Assert-Guard {
    param(
        [Parameter(Mandatory)] [bool] $Condition,
        [Parameter(Mandatory)] [string] $Message
    )
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

$codexPackage = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue
if ($codexPackage) {
    $report = Get-CodexRuntimeGuardReport
    Assert-Guard ($report.schemaVersion -eq 1) "diagnosis schemaVersion"
    Assert-Guard (@($report.checks).Count -ge 10) "expected diagnostic layers"
    Assert-Guard (@($report.checks.id | Sort-Object -Unique).Count -eq @($report.checks).Count) "check IDs must be unique"
    Assert-Guard ($report.acceptanceRequired -eq $true) "acceptance must remain explicit"

    $dryRun = Invoke-CodexRuntimeGuardRepair
    Assert-Guard (-not $dryRun.applied) "repair defaults to dry run"
    Assert-Guard (@($dryRun.actions | Where-Object status -eq "APPLIED").Count -eq 0) "dry run must not apply actions"
}
else {
    Write-Host "Codex AppX is not installed; skipping live-host integration assertions."
}

$module = Get-Module CodexRuntimeGuard
$fixtureRoot = Join-Path $env:TEMP "codex-runtime-guard-test-$PID"
try {
    $currentResources = Join-Path $fixtureRoot "current-resources"
    $backupRoot = Join-Path $fixtureRoot "backups"
    New-Item -ItemType Directory -Path $currentResources -Force | Out-Null

    $manifestPaths = @(
        (Join-Path $fixtureRoot "home-v2.json"),
        (Join-Path $fixtureRoot "local-v2.json")
    )
    $fixture = [pscustomobject]@{
        schemaVersion = 2
        entries = @(
            [pscustomobject]@{
                nativeHostNames = @("com.openai.codexextension")
                paths = [pscustomobject]@{ resourcesPath = "C:\missing-old-resources" }
            }
        )
    }
    foreach ($path in $manifestPaths) {
        $fixture | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding utf8
    }

    $app = [pscustomobject]@{ resourcesPath = $currentResources }
    $dryActions = @(& $module { param($appArg, $pathsArg, $backupArg) Repair-ResourcePaths -App $appArg -ManifestPaths $pathsArg -BackupDirectory $backupArg } $app $manifestPaths $backupRoot)
    Assert-Guard (@($dryActions | Where-Object status -eq "DRY_RUN").Count -eq 2) "resource-path fixture dry run"
    foreach ($path in $manifestPaths) {
        $value = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
        Assert-Guard ($value.entries[0].paths.resourcesPath -eq "C:\missing-old-resources") "dry run must preserve fixture"
    }

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

Write-Host "Codex Runtime Guard self-test passed." -ForegroundColor Green
