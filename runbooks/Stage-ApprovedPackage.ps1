[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProductName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApprovalId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CatalogPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StagingRoot
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetFullPath($Path).TrimEnd("\")
}

function Get-LocalStagingPath {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$LocalRoot
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Staging path '$RelativePath' must be relative to the approved local root."
    }

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw "Staging path must specify a product/version subdirectory."
    }
    $root = Get-NormalizedPath $LocalRoot
    $destination = Get-NormalizedPath (Join-Path $root $RelativePath)

    if (-not $destination.StartsWith("$root\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Resolved staging destination '$destination' is outside '$root'."
    }

    return $destination
}

if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    throw "Approved package catalog was not found at '$catalogPath'."
}

$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$product = @($catalog.products | Where-Object { $_.productName -eq $ProductName })

if ($product.Count -eq 0) {
    throw "Product '$ProductName' is not present in the approved package catalog."
}
if ($product.Count -gt 1) {
    throw "Product '$ProductName' appears more than once in the approved package catalog."
}

$product = $product[0]
if ($product.stagingStatus -ne "ApprovedForStaging") {
    throw "Product '$ProductName' is not approved for staging. Current status: '$($product.stagingStatus)'."
}

foreach ($property in @("approvedVersion", "downloadUrl", "sha256", "stagingRelativePath", "releaseNoteUrl", "artifactVerificationMethod")) {
    if ([string]::IsNullOrWhiteSpace([string]$product.$property)) {
        throw "Product '$ProductName' is missing required '$property' data."
    }
}

if ($product.downloadUrl -notmatch "^https://") {
    throw "Product '$ProductName' must use an HTTPS download URL."
}
if ($product.sha256 -notmatch "^[A-Fa-f0-9]{64}$") {
    throw "Product '$ProductName' must have a 64-character SHA-256 value."
}
if ($product.artifactVerificationMethod -notin @("VendorPublishedSha256", "AuthenticodeAndApprovedHash", "PackageManagerManifest", "InternalCuratedArtifact")) {
    throw "Product '$ProductName' has unsupported artifactVerificationMethod '$($product.artifactVerificationMethod)'."
}
if ($product.artifactVerificationMethod -eq "AuthenticodeAndApprovedHash" -and [string]::IsNullOrWhiteSpace([string]$product.expectedSignerSubject)) {
    throw "Product '$ProductName' must specify expectedSignerSubject when using AuthenticodeAndApprovedHash."
}

$destinationDirectory = Get-LocalStagingPath -RelativePath $product.stagingRelativePath -LocalRoot $stagingRoot
New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null

$downloadUri = [Uri]$product.downloadUrl
$fileName = [System.IO.Path]::GetFileName($downloadUri.AbsolutePath)
if ([string]::IsNullOrWhiteSpace($fileName)) {
    throw "Product '$ProductName' download URL does not include a package file name."
}

$destinationFile = Join-Path $destinationDirectory $fileName
$receiptPath = Join-Path $destinationDirectory "$fileName.staging-receipt.json"

if (Test-Path -LiteralPath $destinationFile -PathType Leaf) {
    $existingHash = (Get-FileHash -LiteralPath $destinationFile -Algorithm SHA256).Hash
    if ($existingHash -eq $product.sha256.ToUpperInvariant()) {
        [pscustomobject]@{
            Status = "AlreadyStagedVerified"
            Product = $product.productName
            Version = $product.approvedVersion
            ApprovalId = $ApprovalId
            PackagePath = $destinationFile
            Sha256 = $existingHash
            ReceiptPath = $receiptPath
        } | ConvertTo-Json -Depth 4
        return
    }

    throw "A different package already exists at '$destinationFile'. Existing SHA-256: $existingHash."
}

$temporaryDirectory = Join-Path $env:TEMP "SrePackageStaging\$([guid]::NewGuid().ToString('N'))"
$temporaryFile = Join-Path $temporaryDirectory $fileName
New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null

try {
    Invoke-WebRequest -Uri $product.downloadUrl -OutFile $temporaryFile -UseBasicParsing -MaximumRedirection 5

    $actualHash = (Get-FileHash -LiteralPath $temporaryFile -Algorithm SHA256).Hash
    if ($actualHash -ne $product.sha256.ToUpperInvariant()) {
        throw "SHA-256 validation failed for '$ProductName'. Expected $($product.sha256); received $actualHash."
    }

    if ([System.IO.Path]::GetExtension($temporaryFile) -in @(".exe", ".msi", ".msix", ".msixbundle")) {
        $signature = Get-AuthenticodeSignature -FilePath $temporaryFile
        if ($signature.Status -ne "Valid") {
            throw "Authenticode signature validation failed for '$ProductName'. Status: $($signature.Status)."
        }
        if (
            -not [string]::IsNullOrWhiteSpace([string]$product.expectedSignerSubject) -and
            $signature.SignerCertificate.Subject -ne $product.expectedSignerSubject
        ) {
            throw "Authenticode signer validation failed for '$ProductName'. Expected '$($product.expectedSignerSubject)'; received '$($signature.SignerCertificate.Subject)'."
        }
    }

    Move-Item -LiteralPath $temporaryFile -Destination $destinationFile -ErrorAction Stop

    $receipt = [ordered]@{
        requestId = $ApprovalId
        status = "StagedVerified"
        stagedAt = (Get-Date).ToUniversalTime().ToString("o")
        product = $product.productName
        approvedVersion = $product.approvedVersion
        releaseNoteUrl = $product.releaseNoteUrl
        sourceUrl = $product.downloadUrl
        sha256 = $actualHash
        artifactVerificationMethod = $product.artifactVerificationMethod
        expectedSignerSubject = $product.expectedSignerSubject
        packagePath = $destinationFile
        rebootRequired = [bool]$product.rebootRequired
    }
    $receipt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $receiptPath -Encoding UTF8

    [pscustomobject]@{
        Status = "StagedVerified"
        Product = $product.productName
        Version = $product.approvedVersion
        ApprovalId = $ApprovalId
        PackagePath = $destinationFile
        Sha256 = $actualHash
        ReceiptPath = $receiptPath
    } | ConvertTo-Json -Depth 4
}
finally {
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}
