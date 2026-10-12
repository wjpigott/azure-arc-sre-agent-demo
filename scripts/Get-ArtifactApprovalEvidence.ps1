[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^https://")]
    [string]$DownloadUrl,

    [Parameter(Mandatory = $true)]
    [ValidatePattern("\.(exe|msi|msix|msixbundle)$")]
    [string]$FileName
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$temporaryDirectory = Join-Path $env:TEMP "SreArtifactEvidence\$([guid]::NewGuid().ToString('N'))"
$temporaryFile = Join-Path $temporaryDirectory $FileName
New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null

try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $temporaryFile -UseBasicParsing -MaximumRedirection 5
    $signature = Get-AuthenticodeSignature -FilePath $temporaryFile

    [pscustomobject]@{
        downloadUrl = $DownloadUrl
        fileName = $FileName
        downloadedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        sha256 = (Get-FileHash -LiteralPath $temporaryFile -Algorithm SHA256).Hash
        signatureStatus = [string]$signature.Status
        signerSubject = $signature.SignerCertificate.Subject
        signerThumbprint = $signature.SignerCertificate.Thumbprint
        timestampSignerSubject = $signature.TimeStamperCertificate.Subject
    } | ConvertTo-Json -Depth 3
}
finally {
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}
