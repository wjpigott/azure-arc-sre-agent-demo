$ErrorActionPreference = "Stop"
$definition = Get-Content -LiteralPath (Join-Path $PSScriptRoot "..\config\chromezip-tested-commands.json") -Raw |
    ConvertFrom-Json
if ($definition.galleryApplicationVersion -ne "157.8103.2" -or
    $definition.packageFileName -ne "ChromeSetup.zip") {
    throw "The tested Chrome ZIP snapshot must identify its original version and package."
}

function Get-CommandTokens {
    param([string]$Source)
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseInput($Source, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count) { throw ($errors | Out-String) }
    return ($tokens | Where-Object {
        $_.Kind -notin @("NewLine", "Semi", "Comment", "EndOfInput")
    } | ForEach-Object { $_.Text }) -join "`n"
}

$bodies = @{}
foreach ($action in @("install", "remove")) {
    $command = [string]$definition.manageActions.$action
    $start = $command.IndexOf('-Command "')
    if ($start -lt 0 -or -not $command.EndsWith('"') -or $command.Length -gt 4096) {
        throw "Unexpected Gallery command wrapper or length for '$action'."
    }
    $start += '-Command "'.Length
    $body = $command.Substring($start, $command.Length - $start - 1)
    $fileName = "Install-ChromeZip.ps1"
    if ($action -eq "remove") { $fileName = "Remove-ChromeZip.ps1" }
    $script = Get-Content -LiteralPath (Join-Path $PSScriptRoot "..\scripts\$fileName") -Raw
    if ((Get-CommandTokens $script) -cne (Get-CommandTokens $body)) {
        throw "'$fileName' differs from the exact published '$action' action."
    }
    $bodies[$action] = $body
}

$mocks = @'
$env:ProgramFiles = 'C:\Mock Program Files'
$script:Present = $false
$script:MissingInstaller = $false
$script:MissingSetup = $false
$script:LeavePresent = $false
$script:Msi = $false
function Expand-Archive {
    param($LiteralPath, $DestinationPath, [switch]$Force)
    if ($LiteralPath -ne 'ChromeSetup.zip' -or $DestinationPath -ne 'chrome_x' -or -not $Force) {
        throw 'Unexpected ZIP extraction.'
    }
}
function Get-ChildItem {
    param($Path, [switch]$Recurse, $Filter, $ErrorAction)
    if ($Filter -eq '*.exe') {
        if (-not $script:MissingInstaller) {
            [pscustomobject]@{FullName='C:\Mock\ChromeSetup.exe'}
        }
    }
    elseif ($Path -like 'HKLM:*') {
        $key = 'Google Chrome'
        if ($script:Msi) { $key = '{11111111-2222-3333-4444-555555555555}' }
        [pscustomobject]@{DisplayName='Google Chrome'; PSChildName=$key}
    }
    elseif (-not $script:MissingSetup) {
        [pscustomobject]@{FullName='C:\Mock\158.0.8127.18\Installer\setup.exe'}
    }
}
function Get-ItemProperty {
    process { $_ }
}
function Get-Process { [pscustomobject]@{Id=12345} }
function Stop-Process {
    param([switch]$Force)
    process {
        if ($_.Id -ne 12345 -or -not $Force) { throw 'Unexpected browser stop.' }
    }
}
function Test-Path { return $script:Present }
function Start-Sleep { throw 'POSTCONDITION_NOT_SATISFIED' }
function Start-Process {
    param($FilePath, $ArgumentList, [switch]$PassThru, [switch]$Wait)
    $arguments = $ArgumentList -join ' '
    if ($FilePath -eq 'C:\Mock\ChromeSetup.exe') {
        if ($arguments -ne '/silent /install' -or -not $PassThru) { throw 'Unexpected install.' }
        $script:Present = -not $script:LeavePresent
    }
    elseif ($FilePath -eq 'msiexec.exe') {
        if ($arguments -ne '/x {11111111-2222-3333-4444-555555555555} /qn /norestart' -or -not $Wait) {
            throw 'Unexpected MSI fallback.'
        }
        $script:Present = $script:LeavePresent
    }
    elseif ($FilePath -eq 'C:\Mock\158.0.8127.18\Installer\setup.exe') {
        if ($arguments -ne '--uninstall --system-level --force-uninstall' -or -not $PassThru) {
            throw 'Unexpected EXE removal.'
        }
        $script:Present = $script:LeavePresent
    }
    else { throw 'An unmocked process must never run.' }
    Write-Host 'MOCK_PROCESS_RAN'
    if ($PassThru) {
        $process = [pscustomobject]@{ExitCode=0}
        $process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { Write-Host 'MOCK_WAITED' }
        return $process
    }
}
'@
$cases = @(
    @{Name="Install"; Action="install"; Setup=""; Success=$true; Ran=$true; Waited=$true; Error="" },
    @{Name="Missing EXE"; Action="install"; Setup='$script:MissingInstaller=$true'; Success=$false; Ran=$false; Waited=$false; Error="Installer exe not found" },
    @{Name="No installed browser"; Action="install"; Setup='$script:LeavePresent=$true'; Success=$false; Ran=$true; Waited=$true; Error="POSTCONDITION_NOT_SATISFIED" },
    @{Name="Remove updated EXE"; Action="remove"; Setup='$script:Present=$true'; Success=$true; Ran=$true; Waited=$true; Error="" },
    @{Name="Already absent"; Action="remove"; Setup=""; Success=$true; Ran=$false; Waited=$false; Error="" },
    @{Name="MSI fallback"; Action="remove"; Setup='$script:Present=$true; $script:Msi=$true'; Success=$true; Ran=$true; Waited=$false; Error="" },
    @{Name="Missing setup"; Action="remove"; Setup='$script:Present=$true; $script:MissingSetup=$true'; Success=$false; Ran=$false; Waited=$false; Error="POSTCONDITION_NOT_SATISFIED" },
    @{Name="Browser remains"; Action="remove"; Setup='$script:Present=$true; $script:LeavePresent=$true'; Success=$false; Ran=$true; Waited=$true; Error="POSTCONDITION_NOT_SATISFIED" }
)
foreach ($case in $cases) {
    $source = $mocks + "`n" + $case.Setup + "`n" + $bodies[$case.Action]
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($source))
    $ErrorActionPreference = "Continue"
    $output = & powershell.exe -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if (($code -eq 0) -ne $case.Success -or
        ($output -match "MOCK_PROCESS_RAN") -ne $case.Ran -or
        ($output -match "MOCK_WAITED") -ne $case.Waited -or
        (-not $case.Success -and $output -notmatch $case.Error)) {
        throw "Failed '$($case.Name)' (exit $code): $output"
    }
}
Write-Output "Passed exact Chrome ZIP command/script parity and $($cases.Count) mocked cases; no real package, browser, or Azure resource was changed."
