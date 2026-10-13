$ErrorActionPreference = "Stop"
$path = Join-Path $PSScriptRoot "..\scripts\Start-ArcVmApplicationCanaryDeployment.ps1"
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
if ($errors.Count) { throw "Deployment wrapper has syntax errors." }
$statements = $ast.EndBlock.Statements
$roleIndex = -1
$check = $null
for ($index = 0; $index -lt $statements.Count; $index++) {
    $statement = $statements[$index]
    if ($statement -is [System.Management.Automation.Language.AssignmentStatementAst]) {
        if ($statement.Left.VariablePath.UserPath -eq "storageRoleAssignments") { $roleIndex = $index }
        if ($statement.Left.VariablePath.UserPath -eq "hasRequiredStorageRole") { $check = $statement.Extent.Text }
    }
}
if ($roleIndex -lt 0 -or -not $check) { throw "Storage role checks were not found." }
$read = $statements[$roleIndex].Extent.Text + "`n" + $statements[$roleIndex + 1].Extent.Text
$storage = [pscustomobject]@{ id = "/subscriptions/storage-scope/resourceGroups/packages/providers/Microsoft.Storage/storageAccounts/packages"; subscriptionId = "storage-scope" }
$galleryIdentityPrincipalId = "gallery-principal"
$requiredStorageRole = "Storage Blob Data Contributor"
function az {
    param([Parameter(ValueFromRemainingArguments = $true)][object[]]$Arguments)
    if (($Arguments[0..2] -join " ") -ne "role assignment list" -or
        $Arguments -contains "--assignee-object-id" -or $Arguments -contains "--assignee" -or
        $Arguments -contains "--fill-principal-name" -or $Arguments -notcontains "--include-inherited") {
        throw "Role discovery must use supported list arguments without directory lookup."
    }
    $subscriptionIndex = [Array]::IndexOf($Arguments, "--subscription")
    $scopeIndex = [Array]::IndexOf($Arguments, "--scope")
    if ($subscriptionIndex -lt 0 -or $Arguments[$subscriptionIndex + 1] -ne $storage.subscriptionId -or
        $scopeIndex -lt 0 -or $Arguments[$scopeIndex + 1] -ne $storage.id) {
        throw "Role lookup must use the package storage subscription and scope."
    }
    $global:LASTEXITCODE = $script:CliExitCode
    ConvertTo-Json -InputObject $script:Assignments
}
$script:CliExitCode = 0
foreach ($case in @(
    @{ Principal = "gallery-principal"; Role = "Storage Blob Data Contributor"; Expected = $true },
    @{ Principal = "different-principal"; Role = "Storage Blob Data Contributor"; Expected = $false },
    @{ Principal = "gallery-principal"; Role = "Storage Blob Data Reader"; Expected = $false },
    @{ Principal = "gallery-principal"; Role = "Contributor"; Expected = $false }
)) {
    $script:Assignments = @([pscustomobject]@{ principalId = $case.Principal; roleDefinitionName = $case.Role })
    Invoke-Expression $read
    Invoke-Expression $check
    if ($hasRequiredStorageRole -ne $case.Expected) { throw "Role/principal matching failed." }
}
$script:Assignments = @()
Invoke-Expression $read
Invoke-Expression $check
if ($hasRequiredStorageRole) { throw "Missing assignments must not pass." }
$script:CliExitCode = 1
$failed = $false
try { Invoke-Expression $read }
catch {
    if ($_.Exception.Message -notmatch "Unable to validate") { throw }
    $failed = $true
}
if (-not $failed) { throw "Role listing failure must be surfaced." }
Write-Output "Passed 6 storage role checks; no Azure command was executed."
