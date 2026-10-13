[CmdletBinding(DefaultParameterSetName = "Install")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Install")]
    [ValidateNotNullOrEmpty()]
    [string]$MsiPath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern("^\d+\.\d+\.\d+\.\d+$")]
    [string]$ExpectedVersion,

    [Parameter(Mandatory = $true, ParameterSetName = "Install")]
    [ValidatePattern("^[A-Fa-f0-9]{64}$")]
    [string]$ExpectedSha256,

    [Parameter(Mandatory = $true, ParameterSetName = "Install")]
    [ValidateNotNullOrEmpty()]
    [string]$ExpectedSignerSubject,

    [Parameter(Mandatory = $true, ParameterSetName = "Uninstall")]
    [switch]$Uninstall,

    [Parameter(Mandatory = $true, ParameterSetName = "Uninstall")]
    [ValidatePattern("^\{[A-Fa-f0-9]{8}-(?:[A-Fa-f0-9]{4}-){3}[A-Fa-f0-9]{12}\}$")]
    [string]$ProductCode
)

$ErrorActionPreference = "Stop"

function Assert-ChromeInstallerAdministrator {
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw "This Chrome Enterprise x64 MSI package requires a 64-bit Windows operating system."
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "Chrome Enterprise MSI requires an elevated administrator or SYSTEM context."
        }
    }
    finally {
        $identity.Dispose()
    }
}

function Get-MachineChromeState {
    $executables = @(
        $env:ProgramW6432,
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)}
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { Join-Path $_ "Google\Chrome\Application\chrome.exe" } |
        Select-Object -Unique

    $files = @(
        foreach ($path in $executables) {
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                $productVersion = (Get-Item -LiteralPath $path).VersionInfo.ProductVersion
                if ($productVersion -notmatch "^(\d+\.\d+\.\d+\.\d+)(?:\s.*)?$") {
                    throw "Chrome executable at '$path' has an unrecognized version '$productVersion'."
                }
                [pscustomobject]@{ Path = $path; Version = $Matches[1] }
            }
        }
    )

    $registrations = @(
        foreach ($view in @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)) {
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $view)
            try {
                $uninstall = $baseKey.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")
                if ($null -ne $uninstall) {
                    try {
                        foreach ($name in $uninstall.GetSubKeyNames()) {
                            $entry = $uninstall.OpenSubKey($name)
                            try {
                                if ($entry.GetValue("DisplayName") -eq "Google Chrome") {
                                    [pscustomobject]@{
                                        Version = [string]$entry.GetValue("DisplayVersion")
                                        ProductCode = $name
                                    }
                                }
                            }
                            finally {
                                if ($null -ne $entry) { $entry.Dispose() }
                            }
                        }
                    }
                    finally { $uninstall.Dispose() }
                }
            }
            finally { $baseKey.Dispose() }
        }
    )

    return [pscustomobject]@{ Files = $files; Registrations = $registrations }
}

function Test-ChromeInstalledVersion {
    param([object]$State, [string]$Version)

    return (
        @($State.Files | Where-Object { $_.Version -eq $Version }).Count -gt 0 -and
        @($State.Registrations | Where-Object { $_.Version -eq $Version }).Count -gt 0
    )
}

function Invoke-ChromeEnterpriseMsiInstall {
    param(
        [string]$PackagePath,
        [string]$Version,
        [string]$Sha256,
        [string]$SignerSubject
    )

    Assert-ChromeInstallerAdministrator
    $fullPath = [IO.Path]::GetFullPath($PackagePath)
    if ([IO.Path]::GetExtension($fullPath) -ne ".msi" -or -not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "An existing Chrome Enterprise MSI is required at '$fullPath'."
    }
    if ((Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash -ne $Sha256) {
        throw "Chrome MSI SHA-256 does not match the approved artifact."
    }
    $signature = Get-AuthenticodeSignature -FilePath $fullPath
    if ($signature.Status -ne "Valid" -or $signature.SignerCertificate.Subject -ne $SignerSubject) {
        throw "Chrome MSI must have a valid Authenticode signature from the exact approved signer."
    }

    $before = Get-MachineChromeState
    foreach ($installed in @($before.Files) + @($before.Registrations)) {
        if ($installed.Version -notmatch "^\d+\.\d+\.\d+\.\d+$") {
            throw "Installed Chrome version '$($installed.Version)' requires manual review."
        }
        if ([version]$installed.Version -gt [version]$Version) {
            throw "Installed Chrome is newer than '$Version'. Automatic downgrade is prohibited."
        }
    }
    if (Test-ChromeInstalledVersion -State $before -Version $Version) {
        return [pscustomobject]@{ Status = "AlreadyInstalledVerified"; Version = $Version; RebootRequired = $false }
    }

    $logDirectory = Join-Path $env:ProgramData "SrePackageDeployment\Logs"
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $logPath = Join-Path $logDirectory "Chrome-$Version-$([guid]::NewGuid().ToString('N')).log"
    $arguments = "/i `"$fullPath`" /qn /norestart ALLUSERS=1 REBOOT=ReallySuppress /L*v `"$logPath`""
    $process = Start-Process -FilePath (Join-Path $env:SystemRoot "System32\msiexec.exe") -ArgumentList $arguments -Wait -PassThru

    if ($process.ExitCode -eq 3010) {
        throw "Chrome MSI requires a reboot (3010). Installation is not verified complete. Arrange a separately approved reboot and revalidate. MSI log: '$logPath'."
    }
    if ($process.ExitCode -ne 0) {
        throw "Chrome MSI failed with exit code $($process.ExitCode). No retry or reboot was performed. MSI log: '$logPath'."
    }

    $after = Get-MachineChromeState
    if (-not (Test-ChromeInstalledVersion -State $after -Version $Version)) {
        throw "Chrome MSI returned 0 but machine-wide registration and executable version '$Version' were not both verified. MSI log: '$logPath'."
    }

    return [pscustomobject]@{
        Status = "InstalledVerified"
        Version = $Version
        InstallationScope = "Machine"
        RebootRequired = $false
        LogPath = $logPath
    }
}

function Invoke-ChromeEnterpriseMsiUninstall {
    param([string]$Code, [string]$Version)

    Assert-ChromeInstallerAdministrator
    if ($Code -notmatch "^\{[A-Fa-f0-9]{8}-(?:[A-Fa-f0-9]{4}-){3}[A-Fa-f0-9]{12}\}$" -or
        $Version -notmatch "^\d+\.\d+\.\d+\.\d+$") {
        throw "Removal requires an approved MSI ProductCode and four-part Chrome version."
    }
    $before = Get-MachineChromeState
    if (@($before.Files).Count -eq 0 -and @($before.Registrations).Count -eq 0) {
        return [pscustomobject]@{ Status = "AlreadyAbsentVerified"; RebootRequired = $false }
    }
    $matchingRegistration = @(
        $before.Registrations |
            Where-Object { $_.ProductCode -eq $Code -and $_.Version -eq $Version }
    )
    if ($matchingRegistration.Count -eq 0) {
        throw "The approved Chrome MSI ProductCode/version is not registered. Manual recovery review is required."
    }
    foreach ($installed in @($before.Files) + @($before.Registrations)) {
        if ($installed.Version -ne $Version) {
            throw "A different Chrome version is present. Automatic removal is prohibited."
        }
    }

    $logDirectory = Join-Path $env:ProgramData "SrePackageDeployment\Logs"
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $logPath = Join-Path $logDirectory "Chrome-Remove-$Version-$([guid]::NewGuid().ToString('N')).log"
    $arguments = "/x $Code /qn /norestart REBOOT=ReallySuppress /L*v `"$logPath`""
    $process = Start-Process -FilePath (Join-Path $env:SystemRoot "System32\msiexec.exe") -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -eq 3010) {
        throw "Chrome removal requires a reboot (3010). Arrange a separately approved reboot and revalidate. MSI log: '$logPath'."
    }
    if ($process.ExitCode -ne 0) {
        throw "Chrome removal failed with exit code $($process.ExitCode). No retry or reboot was performed. MSI log: '$logPath'."
    }
    $after = Get-MachineChromeState
    if (@($after.Files).Count -gt 0 -or @($after.Registrations).Count -gt 0) {
        throw "Chrome removal returned 0 but machine-wide Chrome remains. MSI log: '$logPath'."
    }
    return [pscustomobject]@{
        Status = "RemovedVerified"
        Version = $Version
        ProductCode = $Code
        RebootRequired = $false
        LogPath = $logPath
    }
}

if ($PSCmdlet.ParameterSetName -eq "Uninstall") {
    Invoke-ChromeEnterpriseMsiUninstall -Code $ProductCode -Version $ExpectedVersion | ConvertTo-Json
}
else {
    Invoke-ChromeEnterpriseMsiInstall -PackagePath $MsiPath -Version $ExpectedVersion -Sha256 $ExpectedSha256 -SignerSubject $ExpectedSignerSubject |
        ConvertTo-Json
}
