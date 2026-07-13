[CmdletBinding()]
param(
    [ValidateSet("Diagnose", "Repair")] [string] $Mode = "Diagnose",
    [ValidateSet("All", "ResourcePaths", "ChromeLatest", "NativeHost")] [string[]] $Target = @("All"),
    [switch] $Apply,
    [switch] $Deep,
    [switch] $SaveSnapshot,
    [string] $AccountLabel,
    [string] $WorkspaceLabel,
    [string] $OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "CodexRuntimeGuard.psm1") -Force

if (-not $OutputDirectory) {
    $cursor = Get-Item -LiteralPath $PSScriptRoot
    $workspaceAiRoot = $null
    while ($cursor) {
        $candidate = Join-Path $cursor.FullName ".ai"
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            $workspaceAiRoot = $candidate
            break
        }
        $cursor = $cursor.Parent
    }

    $OutputDirectory = if ($workspaceAiRoot) {
        Join-Path $workspaceAiRoot "state\codex-runtime-guard"
    }
    else {
        Join-Path $env:LOCALAPPDATA "OpenAI\CodexControlRuntimeLab\state\codex-runtime-guard"
    }
}

if ($Mode -eq "Repair") {
    $result = Invoke-CodexRuntimeGuardRepair -Target $Target -Apply:$Apply
    $result.actions | Format-Table target, status, path, message -AutoSize -Wrap
    if (-not $Apply) {
        Write-Host "Dry run only. Re-run with -Apply after reviewing every action." -ForegroundColor Yellow
    }
    elseif ($result.after) {
        Write-Host "Post-repair local status: $($result.after.overall)" -ForegroundColor Cyan
    }
}
else {
    $result = Get-CodexRuntimeGuardReport -AccountLabel $AccountLabel -WorkspaceLabel $WorkspaceLabel -Deep:$Deep
    $result.checks | Format-Table status, layer, id, message -AutoSize -Wrap
    Write-Host "Overall local status: $($result.overall)" -ForegroundColor Cyan
    Write-Host "Account/workspace and per-task tool injection still require the acceptance tasks." -ForegroundColor DarkYellow
}

if ($SaveSnapshot) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $outputPath = Join-Path $OutputDirectory "$stamp-$($Mode.ToLowerInvariant()).json"
    $result | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $outputPath -Encoding utf8
    Write-Host "Snapshot: $outputPath" -ForegroundColor Green
}

if ($Mode -eq "Diagnose") {
    if ($result.overall -eq "FAIL") { exit 2 }
    if ($result.overall -eq "ATTENTION") { exit 1 }
}
