$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "..\scripts\Install-ChromeEnterpriseMsi.ps1"
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors)
if ($errors.Count -gt 0) { throw "Installer script has syntax errors." }
$functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
foreach ($function in $functions) { Invoke-Expression $function.Extent.Text }

function Assert-ChromeInstallerAdministrator {}
function Test-Path { return $true }
function Get-FileHash { return [pscustomobject]@{ Hash = $script:ActualHash } }
function Get-AuthenticodeSignature {
    return [pscustomobject]@{ Status = $script:SignatureStatus; SignerCertificate = [pscustomobject]@{ Subject = $script:ActualSigner } }
}
function New-Item {}
function Get-MachineChromeState {
    $script:StateReads++
    if ($script:StateReads -eq 1) { return $script:Before }
    return $script:After
}
function Start-Process {
    param($FilePath, $ArgumentList, [switch]$Wait, [switch]$PassThru)
    $script:Starts++
    if (-not $Wait -or -not $PassThru -or
        $ArgumentList -notmatch "/qn /norestart" -or $ArgumentList -notmatch '/L\*v "' -or
        $ArgumentList -notmatch "REBOOT=ReallySuppress" -or $FilePath -notmatch "msiexec.exe$") {
        throw "Installer must run synchronously, silently, without reboot, with logging."
    }
    if ($script:Operation -eq "Install" -and $ArgumentList -notmatch "ALLUSERS=1") {
        throw "Installation must be machine-wide."
    }
    if ($script:Operation -eq "Uninstall" -and $ArgumentList -notmatch ("^/x " + [regex]::Escape($script:TestProductCode) + " ")) {
        throw "Removal must target the exact approved MSI ProductCode."
    }
    return [pscustomobject]@{ ExitCode = $script:InstallerExitCode }
}
function New-TestState {
    param([string]$FileVersion, [string]$RegistrationVersion)
    $files = @()
    $registrations = @()
    if ($FileVersion) { $files = @([pscustomobject]@{ Version = $FileVersion }) }
    if ($RegistrationVersion) {     $registrations = @([pscustomobject]@{ Version = $RegistrationVersion; ProductCode = $script:TestProductCode }) }
    return [pscustomobject]@{ Files = $files; Registrations = $registrations }
}
function Reset-Test {
    $script:Operation = "Install"
    $script:TestProductCode = "{11111111-2222-3333-4444-555555555555}"
    $script:ActualHash = "A" * 64
    $script:ActualSigner = "CN=Approved Google Signer"
    $script:SignatureStatus = "Valid"
    $script:InstallerExitCode = 0
    $script:StateReads = 0
    $script:Starts = 0
    $script:Before = New-TestState
    $script:After = New-TestState "144.0.7559.133" "144.0.7559.133"
}
function Invoke-TestInstall {
    Invoke-ChromeEnterpriseMsiInstall -PackagePath "C:\approved packages\chrome.msi" -Version "144.0.7559.133" -Sha256 ("A" * 64) -SignerSubject "CN=Approved Google Signer"
}
function Assert-Rejected {
    param([string]$Pattern)
    $caught = $false
    try { Invoke-TestInstall | Out-Null }
    catch {
        if ($_.Exception.Message -notmatch $Pattern) { throw }
        $caught = $true
    }
    if (-not $caught) { throw "Expected failure matching '$Pattern'." }
}

Reset-Test
$result = Invoke-TestInstall
if ($result.Status -ne "InstalledVerified" -or $script:Starts -ne 1) { throw "Successful install was not verified." }
Reset-Test
$script:Before = $script:After
if ((Invoke-TestInstall).Status -ne "AlreadyInstalledVerified" -or $script:Starts -ne 0) { throw "Verified installs must be idempotent." }
Reset-Test
$script:ActualHash = "B" * 64
Assert-Rejected "SHA-256"
if ($script:Starts -ne 0) { throw "Hash mismatch must block installation." }
Reset-Test
$script:SignatureStatus = "NotSigned"
Assert-Rejected "Authenticode"
Reset-Test
$script:ActualSigner = "CN=Different Publisher"
Assert-Rejected "Authenticode"
Reset-Test
$script:Before = New-TestState "145.0.1.1" "145.0.1.1"
Assert-Rejected "downgrade"
if ($script:Starts -ne 0) { throw "Downgrade must block installation." }
foreach ($code in @(1603, 1618, 1641)) {
    Reset-Test
    $script:InstallerExitCode = $code
    Assert-Rejected "exit code $code"
}
Reset-Test
$script:InstallerExitCode = 3010
Assert-Rejected "requires a reboot"
Reset-Test
$script:After = New-TestState
Assert-Rejected "returned 0"
Reset-Test
$script:After = New-TestState "144.0.7559.133"
Assert-Rejected "returned 0"
Reset-Test
$script:After = New-TestState "" "144.0.7559.133"
Assert-Rejected "returned 0"
Reset-Test
$script:After = New-TestState "143.0.1.1" "143.0.1.1"
Assert-Rejected "returned 0"

function Invoke-TestUninstall {
    $script:Operation = "Uninstall"
    Invoke-ChromeEnterpriseMsiUninstall -Code $script:TestProductCode -Version "144.0.7559.133"
}
function Assert-RemovalRejected {
    param([string]$Pattern)
    $caught = $false
    try { Invoke-TestUninstall | Out-Null }
    catch {
        if ($_.Exception.Message -notmatch $Pattern) { throw }
        $caught = $true
    }
    if (-not $caught) { throw "Expected removal failure matching '$Pattern'." }
}
Reset-Test
if ((Invoke-TestUninstall).Status -ne "AlreadyAbsentVerified" -or $script:Starts -ne 0) {
    throw "Absent Chrome must not run an uninstall."
}
Reset-Test
$script:Before = $script:After
$script:After = New-TestState
if ((Invoke-TestUninstall).Status -ne "RemovedVerified" -or $script:Starts -ne 1) {
    throw "Successful removal was not verified."
}
Reset-Test
$script:Before = New-TestState "144.0.7559.133"
Assert-RemovalRejected "not registered"
if ($script:Starts -ne 0) { throw "Unregistered Chrome must not be removed." }
Reset-Test
$script:Before = $script:After
$script:Before.Registrations[0].ProductCode = "{99999999-2222-3333-4444-555555555555}"
Assert-RemovalRejected "not registered"
if ($script:Starts -ne 0) { throw "Different ProductCode must not be removed." }
Reset-Test
$script:Before = New-TestState "155.0.1.1" "144.0.7559.133"
Assert-RemovalRejected "different Chrome version"
if ($script:Starts -ne 0) { throw "Different Chrome version must not be removed." }
foreach ($code in @(1603, 1605, 1618, 1641)) {
    Reset-Test
    $script:Before = $script:After
    $script:InstallerExitCode = $code
    Assert-RemovalRejected "exit code $code"
}
Reset-Test
$script:Before = $script:After
$script:InstallerExitCode = 3010
Assert-RemovalRejected "requires a reboot"
foreach ($remaining in @(
    (New-TestState "144.0.7559.133"),
    (New-TestState "" "144.0.7559.133")
)) {
    Reset-Test
    $script:Before = $script:After
    $script:After = $remaining
    Assert-RemovalRejected "returned 0"
}
Reset-Test
$script:TestProductCode = "not-a-product-code"
Assert-RemovalRejected "approved MSI ProductCode"
if ($script:Starts -ne 0) { throw "Invalid ProductCode must not start msiexec." }
Write-Output "Passed 27 Chrome MSI install/removal tests; no installer or Azure command was executed."
