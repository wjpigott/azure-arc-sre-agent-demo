$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "Install-ChromeEnterpriseMsi.ps1") `
    -MsiPath (Join-Path $PSScriptRoot "GoogleChromeStandaloneEnterprise64.msi") `
    -ExpectedVersion "<approved-four-part-chrome-version>" `
    -ExpectedSha256 "<approved-msi-sha256>" `
    -ExpectedSignerSubject "<exact-approved-msi-signer-subject>"
