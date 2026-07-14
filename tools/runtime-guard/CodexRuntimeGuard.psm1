Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ChromeExtensionId = "hehggadaopoacecdllhhajmbjkdcmajg"
$script:NativeHostName = "com.openai.codexextension"

function New-GuardCheck {
    param(
        [Parameter(Mandatory)] [string] $Id,
        [Parameter(Mandatory)] [string] $Layer,
        [Parameter(Mandatory)] [ValidateSet("PASS", "WARN", "FAIL", "UNKNOWN")] [string] $Status,
        [Parameter(Mandatory)] [string] $Message,
        [object] $Details = $null,
        [bool] $Repairable = $false
    )

    [pscustomobject]@{
        id = $Id
        layer = $Layer
        status = $Status
        message = $Message
        repairable = $Repairable
        details = $Details
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ exists = $false; valid = $false; value = $null; error = $null }
    }

    try {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
        return [pscustomobject]@{ exists = $true; valid = $true; value = $value; error = $null }
    }
    catch {
        return [pscustomobject]@{ exists = $true; valid = $false; value = $null; error = $_.Exception.Message }
    }
}

function Get-CodexAppState {
    $packages = @(Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue | Sort-Object Version -Descending)
    if ($packages.Count -eq 0) {
        return $null
    }

    $package = $packages[0]
    $resourcesPath = Join-Path $package.InstallLocation "app\resources"
    [pscustomobject]@{
        name = $package.Name
        version = $package.Version.ToString()
        packageFullName = $package.PackageFullName
        installLocation = $package.InstallLocation
        resourcesPath = $resourcesPath
        resourcesExists = Test-Path -LiteralPath $resourcesPath
        codexCliPath = Join-Path $resourcesPath "codex.exe"
        packagedCuaNodePath = Join-Path $resourcesPath "cua_node"
    }
}

function Get-OpenAIDesktopPackageState {
    @(
        Get-AppxPackage -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -in @("OpenAI.Codex", "OpenAI.ChatGPT-Desktop") } |
            Sort-Object Name, Version |
            ForEach-Object {
                [pscustomobject]@{
                    name = $_.Name
                    version = $_.Version.ToString()
                    packageFullName = $_.PackageFullName
                    installLocation = $_.InstallLocation
                }
            }
    )
}

function Get-PluginState {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string[]] $RequiredFiles,
        [bool] $RequireLatest = $false
    )

    $root = Join-Path $HOME ".codex\plugins\cache\openai-bundled\$Name"
    $versionDirectories = @()
    if (Test-Path -LiteralPath $root) {
        $versionDirectories = @(
            Get-ChildItem -LiteralPath $root -Directory -Force |
                Where-Object { $_.Name -ne "latest" -and $_.Name -match '^\d+(\.\d+)+$' } |
                Sort-Object { [version] $_.Name } -Descending
        )
    }

    $latestPath = Join-Path $root "latest"
    $latestItem = Get-Item -LiteralPath $latestPath -Force -ErrorAction SilentlyContinue
    $activePath = if ($latestItem -and (Test-Path -LiteralPath $latestPath)) {
        $latestPath
    }
    elseif ($versionDirectories.Count -gt 0) {
        $versionDirectories[0].FullName
    }
    else {
        $null
    }

    $requiredStates = @()
    foreach ($relativePath in $RequiredFiles) {
        $candidate = if ($activePath) { Join-Path $activePath $relativePath } else { $null }
        $requiredStates += [pscustomobject]@{
            relativePath = $relativePath
            path = $candidate
            exists = [bool] ($candidate -and (Test-Path -LiteralPath $candidate))
        }
    }

    [pscustomobject]@{
        name = $Name
        root = $root
        rootExists = Test-Path -LiteralPath $root
        versions = @($versionDirectories | ForEach-Object { $_.Name })
        newestVersionPath = if ($versionDirectories.Count -gt 0) { $versionDirectories[0].FullName } else { $null }
        latestRequired = $RequireLatest
        latestPath = $latestPath
        latestExists = Test-Path -LiteralPath $latestPath
        latestLinkType = if ($latestItem) { [string] $latestItem.LinkType } else { $null }
        latestTarget = if ($latestItem) { @($latestItem.Target) } else { @() }
        activePath = $activePath
        requiredFiles = $requiredStates
    }
}

function Get-NativeHostState {
    $registryPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$($script:NativeHostName)"
    $registeredManifest = $null
    if (Test-Path -LiteralPath $registryPath) {
        $registeredManifest = (Get-ItemProperty -LiteralPath $registryPath).'(default)'
    }

    $defaultManifest = Join-Path $env:LOCALAPPDATA "OpenAI\extension\$($script:NativeHostName).json"
    $manifestPath = if ($registeredManifest) { $registeredManifest } else { $defaultManifest }
    $manifest = Read-JsonFile -Path $manifestPath
    $hostPath = if ($manifest.valid) { [string] $manifest.value.path } else { $null }

    [pscustomobject]@{
        registryPath = $registryPath
        registryExists = Test-Path -LiteralPath $registryPath
        registeredManifestPath = $registeredManifest
        manifestPath = $manifestPath
        manifestExists = $manifest.exists
        manifestValid = $manifest.valid
        manifestError = $manifest.error
        manifestName = if ($manifest.valid) { [string] $manifest.value.name } else { $null }
        allowedOrigins = if ($manifest.valid) { @($manifest.value.allowed_origins) } else { @() }
        hostPath = $hostPath
        hostExists = [bool] ($hostPath -and (Test-Path -LiteralPath $hostPath))
    }
}

function Get-V2ManifestState {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $ExpectedResourcesPath
    )

    $json = Read-JsonFile -Path $Path
    $entries = @()
    if ($json.valid) {
        $entries = @(
            $json.value.entries | Where-Object {
                @($_.nativeHostNames) -contains $script:NativeHostName
            }
        )
    }

    $entryStates = foreach ($entry in $entries) {
        $pathsProperty = $entry.PSObject.Properties["paths"]
        $paths = if ($pathsProperty -and $null -ne $pathsProperty.Value) {
            $pathsProperty.Value
        }
        else {
            [pscustomobject]@{}
        }
        $pathStates = [ordered]@{}
        foreach ($property in @("browserClientPath", "codexCliPath", "codexHome", "extensionHostPath", "nodePath", "nodeReplPath", "resourcesPath")) {
            $value = if ($paths.PSObject.Properties.Name -contains $property) { [string] $paths.$property } else { $null }
            $pathStates[$property] = [pscustomobject]@{
                path = $value
                exists = [bool] ($value -and (Test-Path -LiteralPath $value))
            }
        }

        [pscustomobject]@{
            entryId = [string] $entry.entryId
            appVersion = [string] $entry.appVersion
            paths = [pscustomobject] $pathStates
            resourcesMatchesCurrentApp = (
                $paths.PSObject.Properties.Name -contains "resourcesPath" -and
                [string] $paths.resourcesPath -eq $ExpectedResourcesPath
            )
        }
    }

    [pscustomobject]@{
        path = $Path
        exists = $json.exists
        valid = $json.valid
        error = $json.error
        matchingEntryCount = $entries.Count
        entries = @($entryStates)
    }
}

function Get-CuaRuntimeState {
    param(
        [Parameter(Mandatory)] [string] $PackagedCuaNodePath,
        [switch] $Deep
    )

    $sourceManifestPath = Join-Path $PackagedCuaNodePath "manifest.json"
    $sourceManifest = Read-JsonFile -Path $sourceManifestPath
    $expectedRuntimeId = $null
    $expectedRuntimeIdError = $null
    if ($sourceManifest.valid) {
        try {
            $expectedRuntimeId = Get-CuaRuntimeId -SourcePath $PackagedCuaNodePath
        }
        catch {
            $expectedRuntimeIdError = $_.Exception.Message
        }
    }
    $runtimeRoot = Join-Path $env:LOCALAPPDATA "OpenAI\Codex\runtimes\cua_node"
    $runtimeStates = @()

    if (Test-Path -LiteralPath $runtimeRoot) {
        foreach ($directory in @(Get-ChildItem -LiteralPath $runtimeRoot -Directory -Force | Where-Object { $_.Name -notmatch '^\.staging-' })) {
            $runtimeManifest = Read-JsonFile -Path (Join-Path $directory.FullName "manifest.json")
            $matchesSource = $false
            if ($sourceManifest.valid -and $runtimeManifest.valid) {
                $matchesSource = (
                    [string] $runtimeManifest.value.runtime_archive_version -eq
                    [string] $sourceManifest.value.runtime_archive_version
                )
            }

            $runtimeState = [ordered]@{
                id = $directory.Name
                path = $directory.FullName
                manifestValid = $runtimeManifest.valid
                runtimeArchiveVersion = if ($runtimeManifest.valid) { [string] $runtimeManifest.value.runtime_archive_version } else { $null }
                matchesPackagedManifest = $matchesSource
                nodeExists = Test-Path -LiteralPath (Join-Path $directory.FullName "bin\node.exe")
                nodeReplExists = Test-Path -LiteralPath (Join-Path $directory.FullName "bin\node_repl.exe")
                computerUseHelperExists = Test-Path -LiteralPath (Join-Path $directory.FullName "bin\node_modules\@oai\sky\bin\windows\codex-computer-use.exe")
            }

            if ($Deep) {
                $files = @(Get-ChildItem -LiteralPath $directory.FullName -Recurse -File -Force)
                $runtimeState.fileCount = $files.Count
                $runtimeState.totalBytes = [long] (($files | Measure-Object Length -Sum).Sum)
            }

            $runtimeStates += [pscustomobject] $runtimeState
        }
    }

    $sourceStats = $null
    if ($Deep -and (Test-Path -LiteralPath $PackagedCuaNodePath)) {
        $sourceFiles = @(Get-ChildItem -LiteralPath $PackagedCuaNodePath -Recurse -File -Force)
        $sourceStats = [pscustomobject]@{
            fileCount = $sourceFiles.Count
            totalBytes = [long] (($sourceFiles | Measure-Object Length -Sum).Sum)
        }
    }

    [pscustomobject]@{
        packagedPath = $PackagedCuaNodePath
        packagedPathExists = Test-Path -LiteralPath $PackagedCuaNodePath
        packagedManifestPath = $sourceManifestPath
        packagedManifestValid = $sourceManifest.valid
        packagedManifestError = $sourceManifest.error
        packagedRuntimeArchiveVersion = if ($sourceManifest.valid) { [string] $sourceManifest.value.runtime_archive_version } else { $null }
        expectedRuntimeId = $expectedRuntimeId
        expectedRuntimeIdError = $expectedRuntimeIdError
        packagedStats = $sourceStats
        runtimeRoot = $runtimeRoot
        runtimes = @($runtimeStates)
        matchingRuntimes = @($runtimeStates | Where-Object matchesPackagedManifest)
    }
}

function Get-ChromeExtensionState {
    $userDataRoot = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data"
    $profiles = @()
    if (Test-Path -LiteralPath $userDataRoot) {
        $profileDirectories = @(
            Get-ChildItem -LiteralPath $userDataRoot -Directory -Force |
                Where-Object { $_.Name -eq "Default" -or $_.Name -match '^Profile \d+$' }
        )
        foreach ($profile in $profileDirectories) {
            $extensionRoot = Join-Path $profile.FullName "Extensions\$($script:ChromeExtensionId)"
            $versions = @()
            if (Test-Path -LiteralPath $extensionRoot) {
                $versions = @(Get-ChildItem -LiteralPath $extensionRoot -Directory -Force | Select-Object -ExpandProperty Name)
            }
            $profiles += [pscustomobject]@{
                profileDirectory = $profile.Name
                installed = $versions.Count -gt 0
                extensionVersions = $versions
            }
        }
    }

    [pscustomobject]@{
        extensionId = $script:ChromeExtensionId
        userDataRoot = $userDataRoot
        profiles = $profiles
        installedProfileCount = @($profiles | Where-Object installed).Count
    }
}

function Get-NamedPipeState {
    try {
        $names = @(Get-ChildItem "\\.\pipe\" | Select-Object -ExpandProperty Name)
        [pscustomobject]@{
            readable = $true
            browserUse = @($names | Where-Object { $_ -match '^codex-browser-use' })
            computerUse = @($names | Where-Object { $_ -match '^codex-computer-use' })
            codexIpc = @($names | Where-Object { $_ -eq 'codex-ipc' })
        }
    }
    catch {
        [pscustomobject]@{
            readable = $false
            error = $_.Exception.Message
            browserUse = @()
            computerUse = @()
            codexIpc = @()
        }
    }
}

function Get-CodexRuntimeGuardReport {
    [CmdletBinding()]
    param(
        [string] $AccountLabel,
        [string] $WorkspaceLabel,
        [switch] $Deep
    )

    $checks = [System.Collections.Generic.List[object]]::new()
    $app = Get-CodexAppState
    if (-not $app) {
        $checks.Add((New-GuardCheck -Id "app.codex" -Layer "local-app" -Status "FAIL" -Message "OpenAI.Codex AppX package was not found."))
        return [pscustomobject]@{
            schemaVersion = 1
            generatedAt = (Get-Date).ToString("o")
            context = [pscustomobject]@{ accountLabel = $AccountLabel; workspaceLabel = $WorkspaceLabel }
            overall = "FAIL"
            acceptanceRequired = $true
            checks = @($checks)
            state = $null
        }
    }

    $checks.Add((New-GuardCheck -Id "app.codex" -Layer "local-app" -Status $(if ($app.resourcesExists) { "PASS" } else { "FAIL" }) -Message "Codex AppX $($app.version); resources path exists=$($app.resourcesExists)." -Details $app))
    $desktopPackages = @(Get-OpenAIDesktopPackageState)
    $checks.Add((New-GuardCheck -Id "app.openai-desktop-packages" -Layer "host-context" -Status "PASS" -Message "Detected $($desktopPackages.Count) OpenAI Codex/ChatGPT desktop package(s). Multiple packages are not a fault, but acceptance must be run from the intended host app." -Details $desktopPackages))

    $chrome = Get-PluginState -Name "chrome" -RequireLatest $true -RequiredFiles @(
        "scripts\browser-client.mjs",
        "extension-host\windows\x64\extension-host.exe",
        "scripts\installManifest.mjs"
    )
    $browser = Get-PluginState -Name "browser" -RequiredFiles @("scripts\browser-client.mjs")
    $computerUse = Get-PluginState -Name "computer-use" -RequiredFiles @("scripts\computer-use-client.mjs")
    foreach ($plugin in @($chrome, $browser, $computerUse)) {
        $missing = @($plugin.requiredFiles | Where-Object { -not $_.exists })
        $latestProblem = $plugin.latestRequired -and -not $plugin.latestExists
        $status = if (-not $plugin.rootExists -or $missing.Count -gt 0 -or $latestProblem) { "FAIL" } else { "PASS" }
        $message = "$($plugin.name): versions=$(@($plugin.versions).Count), active=$($plugin.activePath), missingRequired=$($missing.Count)"
        $checks.Add((New-GuardCheck -Id "plugin.$($plugin.name)" -Layer "plugin-cache" -Status $status -Message $message -Details $plugin -Repairable ($plugin.name -eq "chrome" -and $latestProblem)))
    }

    $nativeHost = Get-NativeHostState
    $nativeHostHealthy = $nativeHost.registryExists -and $nativeHost.manifestValid -and $nativeHost.hostExists
    $checks.Add((New-GuardCheck -Id "chrome.native-host" -Layer "native-messaging" -Status $(if ($nativeHostHealthy) { "PASS" } else { "FAIL" }) -Message "Native Messaging registry=$($nativeHost.registryExists), manifest=$($nativeHost.manifestValid), host=$($nativeHost.hostExists)." -Details $nativeHost -Repairable (-not $nativeHostHealthy)))

    $v2ManifestPaths = @(
        (Join-Path $HOME ".codex\chrome-native-hosts-v2.json"),
        (Join-Path $env:LOCALAPPDATA "OpenAI\Codex\chrome-native-hosts-v2.json")
    )
    $v2States = foreach ($path in $v2ManifestPaths) {
        Get-V2ManifestState -Path $path -ExpectedResourcesPath $app.resourcesPath
    }
    for ($manifestIndex = 0; $manifestIndex -lt $v2States.Count; $manifestIndex++) {
        $manifest = $v2States[$manifestIndex]
        $manifestScope = if ($manifestIndex -eq 0) { "codex-home" } else { "local-app-data" }
        $pathsHealthy = @($manifest.entries | ForEach-Object { $_.paths.PSObject.Properties.Value } | Where-Object { -not $_.exists }).Count -eq 0
        $resourcesCurrent = @($manifest.entries | Where-Object { $_.resourcesMatchesCurrentApp }).Count -gt 0
        $status = if (-not $manifest.exists -or -not $manifest.valid -or $manifest.matchingEntryCount -eq 0 -or -not $pathsHealthy) {
            "FAIL"
        }
        elseif (-not $resourcesCurrent) {
            "WARN"
        }
        else {
            "PASS"
        }
        $checks.Add((New-GuardCheck -Id "chrome.v2-manifest.$manifestScope" -Layer "app-server-manifest" -Status $status -Message "$($manifest.path): entries=$($manifest.matchingEntryCount), pathsHealthy=$pathsHealthy, resourcesCurrent=$resourcesCurrent." -Details $manifest -Repairable (-not $resourcesCurrent -and $manifest.valid)))
    }

    $runtime = Get-CuaRuntimeState -PackagedCuaNodePath $app.packagedCuaNodePath -Deep:$Deep
    $matchingHealthy = @(
        $runtime.matchingRuntimes | Where-Object {
            $_.nodeExists -and $_.nodeReplExists -and $_.computerUseHelperExists
        }
    )
    $runtimeStatus = if (-not $runtime.packagedManifestValid -or $matchingHealthy.Count -eq 0) { "FAIL" } else { "PASS" }
    $runtimeRepairable = (
        $runtime.packagedPathExists -and
        $runtime.packagedManifestValid -and
        $runtime.expectedRuntimeId -and
        $matchingHealthy.Count -eq 0
    )
    $checks.Add((New-GuardCheck -Id "computer-use.runtime" -Layer "relocated-runtime" -Status $runtimeStatus -Message "Packaged runtime=$($runtime.packagedRuntimeArchiveVersion); matching healthy runtimes=$($matchingHealthy.Count)." -Details $runtime -Repairable $runtimeRepairable))

    $extension = Get-ChromeExtensionState
    $extensionStatus = if ($extension.installedProfileCount -gt 0) { "PASS" } else { "WARN" }
    $checks.Add((New-GuardCheck -Id "chrome.extension" -Layer "chrome-profile" -Status $extensionStatus -Message "ChatGPT Chrome extension is installed in $($extension.installedProfileCount) detected profile(s)." -Details $extension))

    $pipes = Get-NamedPipeState
    $pipeStatus = if (-not $pipes.readable) { "UNKNOWN" } else { "PASS" }
    $checks.Add((New-GuardCheck -Id "runtime.pipes" -Layer "live-process" -Status $pipeStatus -Message "Live pipes: browser=$($pipes.browserUse.Count), computerUse=$($pipes.computerUse.Count). Absence is not a failure when no control task is active." -Details $pipes))

    $accountStatus = if ($AccountLabel -or $WorkspaceLabel) { "UNKNOWN" } else { "UNKNOWN" }
    $checks.Add((New-GuardCheck -Id "account.capability" -Layer "account-workspace" -Status $accountStatus -Message "Local files cannot prove plan, rollout, workspace policy, or per-task tool injection. Run the official acceptance tasks after an account/workspace switch." -Details ([pscustomobject]@{ accountLabel = $AccountLabel; workspaceLabel = $WorkspaceLabel })))

    $locallyDecidableChecks = @($checks | Where-Object layer -ne "account-workspace")
    $overall = if (@($locallyDecidableChecks | Where-Object status -eq "FAIL").Count -gt 0) {
        "FAIL"
    }
    elseif (@($locallyDecidableChecks | Where-Object { $_.status -in @("WARN", "UNKNOWN") }).Count -gt 0) {
        "ATTENTION"
    }
    else {
        "PASS"
    }

    [pscustomobject]@{
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("o")
        context = [pscustomobject]@{
            computerName = $env:COMPUTERNAME
            windowsUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            windowsUserSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            accountLabel = $AccountLabel
            workspaceLabel = $WorkspaceLabel
            deep = [bool] $Deep
        }
        overall = $overall
        acceptanceRequired = $true
        checks = @($checks)
        state = [pscustomobject]@{
            app = $app
            openAIDesktopPackages = $desktopPackages
            plugins = [pscustomobject]@{ chrome = $chrome; browser = $browser; computerUse = $computerUse }
            nativeHost = $nativeHost
            v2Manifests = @($v2States)
            cuaRuntime = $runtime
            chromeExtension = $extension
            namedPipes = $pipes
        }
    }
}

function Backup-GuardFile {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $BackupDirectory
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    $name = [IO.Path]::GetFileName($Path)
    $parentHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes((Split-Path $Path -Parent)))).Substring(0, 8).ToLowerInvariant()
    $destination = Join-Path $BackupDirectory "$parentHash-$name"
    Copy-Item -LiteralPath $Path -Destination $destination -Force
    $destination
}

function Get-CuaRuntimeId {
    param([Parameter(Mandatory)] [string] $SourcePath)

    $fingerprintFiles = @(
        [pscustomobject]@{ name = "manifest.json"; path = "manifest.json" },
        [pscustomobject]@{ name = "bin/node.exe"; path = "bin\node.exe" },
        [pscustomobject]@{ name = "bin/node_repl.exe"; path = "bin\node_repl.exe" }
    )
    $segments = foreach ($file in $fingerprintFiles) {
        $fullPath = Join-Path $SourcePath $file.path
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            throw "Packaged CUA runtime fingerprint file is missing: $fullPath"
        }
        $digest = (Get-FileHash -Algorithm SHA256 -LiteralPath $fullPath).Hash.ToLowerInvariant()
        "$($file.name)`0$digest`0"
    }

    $payload = [Text.Encoding]::UTF8.GetBytes(($segments -join ""))
    $digestBytes = [Security.Cryptography.SHA256]::HashData($payload)
    [Convert]::ToHexString($digestBytes).ToLowerInvariant().Substring(0, 16)
}

function Copy-GuardDirectoryContent {
    param(
        [Parameter(Mandatory)] [string] $SourcePath,
        [Parameter(Mandatory)] [string] $DestinationPath
    )

    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    foreach ($directory in @(Get-ChildItem -LiteralPath $SourcePath -Recurse -Force -Directory)) {
        $relative = [IO.Path]::GetRelativePath($SourcePath, $directory.FullName)
        New-Item -ItemType Directory -Path (Join-Path $DestinationPath $relative) -Force | Out-Null
    }

    $copiedFiles = 0
    foreach ($file in @(Get-ChildItem -LiteralPath $SourcePath -Recurse -Force -File)) {
        $relative = [IO.Path]::GetRelativePath($SourcePath, $file.FullName)
        $target = Join-Path $DestinationPath $relative
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null

        # Stream the content instead of copying metadata. WindowsApps files can carry
        # Application Protected EFS attributes that cannot be recreated in LocalAppData.
        $input = [IO.File]::Open($file.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try {
            $output = [IO.File]::Open($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try {
                $input.CopyTo($output)
            }
            finally {
                $output.Dispose()
            }
        }
        finally {
            $input.Dispose()
        }
        $copiedFiles++
    }
    $copiedFiles
}

function Repair-CuaRuntime {
    param(
        [Parameter(Mandatory)] [object] $RuntimeState,
        [switch] $Apply
    )

    if (-not $RuntimeState.packagedPathExists -or -not $RuntimeState.packagedManifestValid) {
        return [pscustomobject]@{ target = "cuaRuntime"; path = $RuntimeState.packagedPath; status = "REFUSED"; message = "Packaged CUA runtime or its manifest is unavailable." }
    }

    $healthyMatch = @($RuntimeState.matchingRuntimes | Where-Object {
        $_.manifestValid -and $_.nodeExists -and $_.nodeReplExists -and $_.computerUseHelperExists
    })
    if ($healthyMatch.Count -gt 0) {
        return [pscustomobject]@{ target = "cuaRuntime"; path = $healthyMatch[0].path; status = "NOOP"; message = "Current packaged CUA runtime is already relocated and healthy." }
    }

    $source = [string] $RuntimeState.packagedPath
    $runtimeId = Get-CuaRuntimeId -SourcePath $source
    $destination = Join-Path $RuntimeState.runtimeRoot $runtimeId
    $requiredPaths = @(
        "manifest.json",
        "bin\node.exe",
        "bin\node_repl.exe",
        "bin\node_modules",
        "bin\node_modules\@oai\sky\bin\windows\codex-computer-use.exe"
    )
    $missingSourcePaths = @($requiredPaths | Where-Object { -not (Test-Path -LiteralPath (Join-Path $source $_)) })
    if ($missingSourcePaths.Count -gt 0) {
        return [pscustomobject]@{ target = "cuaRuntime"; path = $source; status = "REFUSED"; message = "Packaged CUA runtime is incomplete: $($missingSourcePaths -join ', ')." }
    }
    if (Test-Path -LiteralPath $destination) {
        return [pscustomobject]@{ target = "cuaRuntime"; path = $destination; status = "REFUSED"; message = "Expected destination exists but did not pass health checks; refusing to overwrite it." }
    }
    if (-not $Apply) {
        return [pscustomobject]@{ target = "cuaRuntime"; path = $destination; status = "DRY_RUN"; message = "Would stream-copy the packaged runtime without Application Protected metadata, verify it, and atomically enable runtime $runtimeId." }
    }

    New-Item -ItemType Directory -Path $RuntimeState.runtimeRoot -Force | Out-Null
    $staging = Join-Path $RuntimeState.runtimeRoot ".staging-$runtimeId-$([guid]::NewGuid().ToString('N'))"
    try {
        $copiedFiles = Copy-GuardDirectoryContent -SourcePath $source -DestinationPath $staging
        foreach ($relative in $requiredPaths) {
            if (-not (Test-Path -LiteralPath (Join-Path $staging $relative))) {
                throw "Relocated CUA runtime is missing required path: $relative"
            }
        }
        foreach ($relative in @("manifest.json", "bin\node.exe", "bin\node_repl.exe")) {
            $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $source $relative)).Hash
            $stagingHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $staging $relative)).Hash
            if ($sourceHash -ne $stagingHash) {
                throw "Relocated CUA runtime hash mismatch: $relative"
            }
        }

        $sourceStats = @(Get-ChildItem -LiteralPath $source -Recurse -Force -File | Measure-Object -Property Length -Sum)
        $stagingStats = @(Get-ChildItem -LiteralPath $staging -Recurse -Force -File | Measure-Object -Property Length -Sum)
        if ($sourceStats[0].Count -ne $stagingStats[0].Count -or [long] $sourceStats[0].Sum -ne [long] $stagingStats[0].Sum) {
            throw "Relocated CUA runtime file count or byte total does not match the packaged source."
        }
        Move-Item -LiteralPath $staging -Destination $destination
    }
    catch {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }

    [pscustomobject]@{
        target = "cuaRuntime"
        path = $destination
        status = "APPLIED"
        message = "Relocated runtime $runtimeId with $copiedFiles verified file(s)."
        runtimeId = $runtimeId
    }
}

function Repair-ResourcePaths {
    param(
        [Parameter(Mandatory)] [object] $App,
        [Parameter(Mandatory)] [string[]] $ManifestPaths,
        [Parameter(Mandatory)] [string] $BackupDirectory,
        [switch] $Apply
    )

    $actions = @()
    foreach ($path in $ManifestPaths) {
        $json = Read-JsonFile -Path $path
        if (-not $json.valid) {
            $actions += [pscustomobject]@{ target = "resourcesPath"; path = $path; status = "REFUSED"; message = "Manifest is missing or invalid." }
            continue
        }

        $matchingEntries = @($json.value.entries | Where-Object { @($_.nativeHostNames) -contains $script:NativeHostName })
        if ($matchingEntries.Count -eq 0) {
            $actions += [pscustomobject]@{ target = "resourcesPath"; path = $path; status = "REFUSED"; message = "No Codex Chrome native-host entry exists." }
            continue
        }

        $entriesWithoutPaths = @($matchingEntries | Where-Object {
            -not ($_.PSObject.Properties.Name -contains "paths") -or $null -eq $_.paths
        })
        if ($entriesWithoutPaths.Count -gt 0) {
            $actions += [pscustomobject]@{ target = "resourcesPath"; path = $path; status = "REFUSED"; message = "$($entriesWithoutPaths.Count) matching entry/entries lack a paths object." }
            continue
        }

        $stale = @($matchingEntries | Where-Object {
            $property = $_.paths.PSObject.Properties["resourcesPath"]
            -not $property -or [string] $property.Value -ne $App.resourcesPath
        })
        if ($stale.Count -eq 0) {
            $actions += [pscustomobject]@{ target = "resourcesPath"; path = $path; status = "NOOP"; message = "Already points to the current AppX resources path." }
            continue
        }

        if (-not $Apply) {
            $actions += [pscustomobject]@{ target = "resourcesPath"; path = $path; status = "DRY_RUN"; message = "Would update $($stale.Count) entry/entries to $($App.resourcesPath)." }
            continue
        }

        $backup = Backup-GuardFile -Path $path -BackupDirectory $BackupDirectory
        foreach ($entry in $stale) {
            if ($entry.paths.PSObject.Properties.Name -contains "resourcesPath") {
                $entry.paths.resourcesPath = $App.resourcesPath
            }
            else {
                $entry.paths | Add-Member -NotePropertyName "resourcesPath" -NotePropertyValue $App.resourcesPath
            }
        }
        $json.value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path -Encoding utf8
        $verify = Read-JsonFile -Path $path
        $postconditionFailed = $true
        if ($verify.valid) {
            $verifiedEntries = @($verify.value.entries | Where-Object { @($_.nativeHostNames) -contains $script:NativeHostName })
            $postconditionFailed = @($verifiedEntries | Where-Object {
                -not ($_.PSObject.Properties.Name -contains "paths") -or
                $null -eq $_.paths -or
                -not ($_.paths.PSObject.Properties.Name -contains "resourcesPath") -or
                [string] $_.paths.resourcesPath -ne $App.resourcesPath
            }).Count -gt 0
        }
        if (-not $verify.valid -or $postconditionFailed) {
            Copy-Item -LiteralPath $backup -Destination $path -Force
            throw "Updated manifest failed validation or its resourcesPath postcondition and was rolled back: $path"
        }
        $actions += [pscustomobject]@{ target = "resourcesPath"; path = $path; status = "APPLIED"; message = "Updated to current AppX resources path."; backup = $backup }
    }
    $actions
}

function Repair-ChromeLatest {
    param(
        [Parameter(Mandatory)] [object] $Plugin,
        [switch] $Apply
    )

    if ($Plugin.latestExists) {
        return [pscustomobject]@{ target = "chromeLatest"; path = $Plugin.latestPath; status = "NOOP"; message = "latest already resolves." }
    }
    if (-not $Plugin.newestVersionPath) {
        return [pscustomobject]@{ target = "chromeLatest"; path = $Plugin.latestPath; status = "REFUSED"; message = "No version directory is available." }
    }

    $requiredHost = Join-Path $Plugin.newestVersionPath "extension-host\windows\x64\extension-host.exe"
    $requiredClient = Join-Path $Plugin.newestVersionPath "scripts\browser-client.mjs"
    if (-not (Test-Path -LiteralPath $requiredHost) -or -not (Test-Path -LiteralPath $requiredClient)) {
        return [pscustomobject]@{ target = "chromeLatest"; path = $Plugin.latestPath; status = "REFUSED"; message = "Newest version is incomplete." }
    }

    $existingItem = Get-Item -LiteralPath $Plugin.latestPath -Force -ErrorAction SilentlyContinue
    if ($existingItem -and $existingItem.LinkType -notin @("Junction", "SymbolicLink")) {
        return [pscustomobject]@{ target = "chromeLatest"; path = $Plugin.latestPath; status = "REFUSED"; message = "latest exists as a regular directory; refusing to replace it." }
    }

    if (-not $Apply) {
        return [pscustomobject]@{ target = "chromeLatest"; path = $Plugin.latestPath; status = "DRY_RUN"; message = "Would point latest to $($Plugin.newestVersionPath)." }
    }

    if ($existingItem) {
        Remove-Item -LiteralPath $Plugin.latestPath -Force
    }
    New-Item -ItemType Junction -Path $Plugin.latestPath -Target $Plugin.newestVersionPath | Out-Null
    [pscustomobject]@{ target = "chromeLatest"; path = $Plugin.latestPath; status = "APPLIED"; message = "Created Junction to $($Plugin.newestVersionPath)." }
}

function Repair-NativeHost {
    param(
        [Parameter(Mandatory)] [object] $App,
        [Parameter(Mandatory)] [object] $ChromePlugin,
        [Parameter(Mandatory)] [object] $NativeHost,
        [switch] $Apply
    )

    if ($NativeHost.registryExists -and $NativeHost.manifestValid -and $NativeHost.hostExists) {
        return [pscustomobject]@{ target = "nativeHost"; status = "NOOP"; message = "Native Messaging registration is healthy." }
    }

    $installer = if ($ChromePlugin.activePath) { Join-Path $ChromePlugin.activePath "scripts\installManifest.mjs" } else { $null }
    $nodePath = Join-Path $App.resourcesPath "cua_node\bin\node.exe"
    $nodeReplPath = Join-Path $App.resourcesPath "cua_node\bin\node_repl.exe"
    $runnerNode = Get-Command node -ErrorAction SilentlyContinue
    $requirements = @($installer, $App.codexCliPath, $nodePath, $nodeReplPath)
    if (-not $runnerNode -or @($requirements | Where-Object { -not $_ -or -not (Test-Path -LiteralPath $_) }).Count -gt 0) {
        return [pscustomobject]@{ target = "nativeHost"; status = "REFUSED"; message = "Official installer or a runnable system Node is unavailable." }
    }

    if (-not $Apply) {
        return [pscustomobject]@{ target = "nativeHost"; status = "DRY_RUN"; message = "Would run the bundled installManifest.mjs with current AppX runtime paths." }
    }

    $tempScript = Join-Path $env:TEMP "codex-runtime-guard-install-native-host-$PID.mjs"
    $oldValues = @{
        CODEX_GUARD_INSTALLER = $env:CODEX_GUARD_INSTALLER
        CODEX_GUARD_CLI = $env:CODEX_GUARD_CLI
        CODEX_GUARD_NODE = $env:CODEX_GUARD_NODE
        CODEX_GUARD_NODE_REPL = $env:CODEX_GUARD_NODE_REPL
    }
    try {
        $env:CODEX_GUARD_INSTALLER = $installer
        $env:CODEX_GUARD_CLI = $App.codexCliPath
        $env:CODEX_GUARD_NODE = $nodePath
        $env:CODEX_GUARD_NODE_REPL = $nodeReplPath
        @'
import { pathToFileURL } from "node:url";
const { install } = await import(pathToFileURL(process.env.CODEX_GUARD_INSTALLER).href);
await install({
  appServerRuntimePaths: {
    codexCliPath: process.env.CODEX_GUARD_CLI,
    nodePath: process.env.CODEX_GUARD_NODE,
    nodeReplPath: process.env.CODEX_GUARD_NODE_REPL,
  },
});
'@ | Set-Content -LiteralPath $tempScript -Encoding utf8
        & $runnerNode.Source $tempScript
        if ($LASTEXITCODE -ne 0) {
            throw "Bundled native-host installer exited with code $LASTEXITCODE."
        }
    }
    finally {
        Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
        foreach ($key in $oldValues.Keys) {
            [Environment]::SetEnvironmentVariable($key, $oldValues[$key], "Process")
        }
    }

    [pscustomobject]@{ target = "nativeHost"; status = "APPLIED"; message = "Ran bundled installManifest.mjs." }
}

function Invoke-CodexRuntimeGuardRepair {
    [CmdletBinding()]
    param(
        [ValidateSet("All", "ResourcePaths", "ChromeLatest", "NativeHost", "CuaRuntime")] [string[]] $Target = @("All"),
        [switch] $Apply,
        [string] $BackupRoot
    )

    $before = Get-CodexRuntimeGuardReport
    if (-not $before.state) {
        throw "Codex AppX state is unavailable; repair cannot continue."
    }

    if (-not $BackupRoot) {
        $BackupRoot = Join-Path $env:LOCALAPPDATA "OpenAI\Codex\runtime-guard-backups"
    }
    $runId = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $backupDirectory = Join-Path $BackupRoot $runId
    $targets = if ($Target -contains "All") { @("ChromeLatest", "NativeHost", "ResourcePaths", "CuaRuntime") } else { @($Target) }
    $actions = @()

    if ($targets -contains "ChromeLatest") {
        $actions += Repair-ChromeLatest -Plugin $before.state.plugins.chrome -Apply:$Apply
    }

    if ($targets -contains "NativeHost") {
        $refreshedChrome = Get-PluginState -Name "chrome" -RequireLatest $true -RequiredFiles @(
            "scripts\browser-client.mjs",
            "extension-host\windows\x64\extension-host.exe",
            "scripts\installManifest.mjs"
        )
        $actions += Repair-NativeHost -App $before.state.app -ChromePlugin $refreshedChrome -NativeHost $before.state.nativeHost -Apply:$Apply
    }

    if ($targets -contains "ResourcePaths") {
        $manifestPaths = @($before.state.v2Manifests | Select-Object -ExpandProperty path)
        $actions += Repair-ResourcePaths -App $before.state.app -ManifestPaths $manifestPaths -BackupDirectory $backupDirectory -Apply:$Apply
    }

    if ($targets -contains "CuaRuntime") {
        $actions += Repair-CuaRuntime -RuntimeState $before.state.cuaRuntime -Apply:$Apply
    }

    [pscustomobject]@{
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("o")
        applied = [bool] $Apply
        backupDirectory = if ($Apply -and (Test-Path -LiteralPath $backupDirectory)) { $backupDirectory } else { $null }
        actions = @($actions)
        beforeOverall = $before.overall
        after = if ($Apply) { Get-CodexRuntimeGuardReport } else { $null }
    }
}

Export-ModuleMember -Function Get-CodexRuntimeGuardReport, Invoke-CodexRuntimeGuardRepair
