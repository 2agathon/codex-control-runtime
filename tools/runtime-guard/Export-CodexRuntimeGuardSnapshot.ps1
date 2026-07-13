[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $InputPath,
    [string] $OutputPath,
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
if (-not $OutputPath) {
    $directory = Split-Path -Parent $resolvedInput
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($resolvedInput)
    $OutputPath = Join-Path $directory "$stem.public.json"
}

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
if ($resolvedInput -eq $resolvedOutput) {
    throw "OutputPath must not overwrite the raw snapshot."
}
if ((Test-Path -LiteralPath $resolvedOutput) -and -not $Force) {
    throw "Output already exists. Use -Force to replace it: $resolvedOutput"
}

$sensitiveNames = @(
    "machineName", "windowsUser", "windowsUserSid", "accountLabel", "workspaceLabel",
    "token", "accessToken", "refreshToken", "password", "cookie", "cookies", "secret", "apiKey"
)
$sensitiveNameSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in $sensitiveNames) { [void] $sensitiveNameSet.Add($name) }

$replacementPairs = @(
    [pscustomobject]@{ Value = $env:LOCALAPPDATA; Replacement = "%LOCALAPPDATA%" },
    [pscustomobject]@{ Value = $env:APPDATA; Replacement = "%APPDATA%" },
    [pscustomobject]@{ Value = $env:USERPROFILE; Replacement = "%USERPROFILE%" },
    [pscustomobject]@{ Value = $env:TEMP; Replacement = "%TEMP%" },
    [pscustomobject]@{ Value = $env:COMPUTERNAME; Replacement = "REDACTED-MACHINE" },
    [pscustomobject]@{ Value = $env:USERNAME; Replacement = "REDACTED-USER" }
) | Where-Object { $_.Value } | Sort-Object { $_.Value.Length } -Descending

function Convert-PublicString {
    param([Parameter(Mandatory)] [string] $Value)

    $result = $Value
    foreach ($pair in $replacementPairs) {
        $result = $result.Replace([string] $pair.Value, [string] $pair.Replacement, [System.StringComparison]::OrdinalIgnoreCase)
    }
    $result = $result -replace 'S-1-5-21-(?:\d+-){3}\d+', 'REDACTED-SID'
    $result = $result -replace '(?i)(Google[\\/]+Chrome[\\/]+User Data[\\/]+)([^\\/\"]+)', '$1REDACTED-PROFILE'
    $result
}

function Convert-ToPublicValue {
    param(
        [AllowNull()] $Value,
        [string] $PropertyName
    )

    if ($PropertyName -and $sensitiveNameSet.Contains($PropertyName)) {
        return "REDACTED"
    }
    if ($null -eq $Value) { return $null }
    if ($Value -is [string]) { return Convert-PublicString -Value $Value }
    if ($Value -is [ValueType]) { return $Value }
    if ($Value -is [System.Collections.IDictionary]) {
        $copy = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $copy[$key] = Convert-ToPublicValue -Value $Value[$key] -PropertyName ([string] $key)
        }
        return [pscustomobject] $copy
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @($Value | ForEach-Object { Convert-ToPublicValue -Value $_ })
        Write-Output -NoEnumerate $items
        return
    }

    $properties = @($Value.PSObject.Properties | Where-Object MemberType -in @("NoteProperty", "Property"))
    if ($properties.Count -eq 0) { return $Value }

    $copy = [ordered]@{}
    foreach ($property in $properties) {
        $copy[$property.Name] = Convert-ToPublicValue -Value $property.Value -PropertyName $property.Name
    }
    [pscustomobject] $copy
}

$snapshot = Get-Content -Raw -LiteralPath $resolvedInput | ConvertFrom-Json
$publicSnapshot = Convert-ToPublicValue -Value $snapshot
$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
$publicSnapshot | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $resolvedOutput -Encoding utf8

Write-Host "Public snapshot: $resolvedOutput" -ForegroundColor Green
