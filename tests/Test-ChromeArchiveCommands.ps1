$ErrorActionPreference = "Stop"

$documents = @(
    (Join-Path $PSScriptRoot "..\docs\arc-vm-applications-deployment.md")
)
$commands = @()
foreach ($document in $documents) {
    $examples = @(Select-String -LiteralPath $document -Pattern '^powershell\.exe .*Expand-Archive' |
        ForEach-Object { $_.Line })
    if ($examples.Count -ne 2 -or @($examples | Where-Object { $_ -match '\btar(?:\.exe)?\b' }).Count) {
        throw "Expected tar-free Chrome install and removal examples in '$document'."
    }
    if ($commands.Count -eq 0) { $commands = $examples }
    elseif ($commands[0] -cne $examples[0] -or $commands[1] -cne $examples[1]) {
        throw "Chrome packaging commands differ between documents."
    }
}

function Assert-CommandResult {
    param([string]$Command, [bool]$ExpectSuccess)

    $ErrorActionPreference = "Continue"
    $output = & $env:ComSpec /d /c $Command 2>&1
    $code = $LASTEXITCODE
    if (($code -eq 0) -ne $ExpectSuccess) {
        throw "Unexpected command exit code ${code}: $($output | Out-String)"
    }
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("Chrome archive tests " + [guid]::NewGuid().ToString("N"))
$fixtureRoot = Join-Path $testRoot "fixtures"
$archive = Join-Path $testRoot "chrome-enterprise-msi.zip"
$installMarker = Join-Path $testRoot "ChromePackage\install-invoked.txt"
$removeMarker = Join-Path $testRoot "ChromePackage\remove-invoked.txt"
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
$locationPushed = $false
try {
    Set-Content -LiteralPath (Join-Path $fixtureRoot "Install-Chrome.ps1") -Value @'
$ErrorActionPreference = "Stop"
Add-Content -LiteralPath (Join-Path $PSScriptRoot "install-invoked.txt") -Value "invoked"
'@
    Set-Content -LiteralPath (Join-Path $fixtureRoot "Install-ChromeEnterpriseMsi.ps1") -Value @'
param([switch]$Uninstall, [string]$ProductCode, [string]$ExpectedVersion)
$ErrorActionPreference = "Stop"
if (-not $Uninstall -or $ProductCode -ne "{11111111-2222-3333-4444-555555555555}" -or
    $ExpectedVersion -ne "156.0.8078.48") {
    throw "Reviewed removal parameters were not passed correctly."
}
Set-Content -LiteralPath (Join-Path $PSScriptRoot "remove-invoked.txt") -Value "invoked"
'@
    Compress-Archive -Path (Join-Path $fixtureRoot "*") -DestinationPath $archive
    Push-Location $testRoot
    $locationPushed = $true
    Assert-CommandResult -Command $commands[0] -ExpectSuccess $true
    if (-not (Test-Path -LiteralPath $installMarker)) { throw "Install launcher did not run." }
    Assert-CommandResult -Command $commands[0] -ExpectSuccess $true
    if (@(Get-Content -LiteralPath $installMarker).Count -ne 2) {
        throw "Repeat extraction did not invoke the launcher."
    }
    $remove = $commands[1].Replace("<approved-msi-product-code-in-braces>", "{11111111-2222-3333-4444-555555555555}").
        Replace("<approved-four-part-chrome-version>", "156.0.8078.48")
    Assert-CommandResult -Command $remove -ExpectSuccess $true
    if (-not (Test-Path -LiteralPath $removeMarker)) { throw "Removal helper did not run." }

    Remove-Item -LiteralPath $installMarker, $removeMarker, $archive -Force
    foreach ($command in $commands) {
        Assert-CommandResult -Command $command -ExpectSuccess $false
    }
    [IO.File]::WriteAllText($archive, "not a ZIP archive")
    foreach ($command in $commands) {
        Assert-CommandResult -Command $command -ExpectSuccess $false
    }
    if ((Test-Path -LiteralPath $installMarker) -or (Test-Path -LiteralPath $removeMarker)) {
        throw "Failed extraction must not invoke stale extracted scripts."
    }

    Set-Content -LiteralPath (Join-Path $fixtureRoot "Install-Chrome.ps1") -Value 'throw "Simulated installer failure."'
    Compress-Archive -Path (Join-Path $fixtureRoot "*") -DestinationPath $archive -Force
    Assert-CommandResult -Command $commands[0] -ExpectSuccess $false
}
finally {
    if ($locationPushed) { Pop-Location }
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
Write-Output "Passed Chrome archive command checks: install, repeat extraction, removal parameters, missing/corrupt ZIPs, and installer failure; no MSI or Azure command was executed."
