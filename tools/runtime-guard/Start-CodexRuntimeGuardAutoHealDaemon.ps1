[CmdletBinding()]
param(
    [timespan] $Interval = (New-TimeSpan -Minutes 10),
    [string] $StateDirectory = (Join-Path $env:LOCALAPPDATA "OpenAI\CodexControlRuntimeLab\auto-heal")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Interval -lt (New-TimeSpan -Minutes 5)) {
    throw "Interval must be at least five minutes."
}

$autoHealScript = Join-Path $PSScriptRoot "Invoke-CodexRuntimeGuardAutoHeal.ps1"
if (-not (Test-Path -LiteralPath $autoHealScript -PathType Leaf)) {
    throw "Auto-Heal script is missing: $autoHealScript"
}

New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$identityHash = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($identity))
).Substring(0, 12)
$mutex = [Threading.Mutex]::new($false, "Local\CodexRuntimeGuardAutoHealDaemon-$identityHash")
$lockAcquired = $false

try {
    $lockAcquired = $mutex.WaitOne(0)
    if (-not $lockAcquired) {
        return
    }

    while ($true) {
        try {
            & $autoHealScript -StateDirectory $StateDirectory | Out-Null
        }
        catch {
            $failure = [pscustomobject]@{
                schemaVersion = 1
                checkedAt = (Get-Date).ToString("o")
                event = "DAEMON_RUN_FAILED"
                message = $_.Exception.Message
            }
            ($failure | ConvertTo-Json -Compress) |
                Add-Content -LiteralPath (Join-Path $StateDirectory "daemon-errors.jsonl") -Encoding utf8
        }

        Start-Sleep -Seconds ([int] $Interval.TotalSeconds)
    }
}
finally {
    if ($lockAcquired) {
        [void] $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
}
