$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$catalog = Get-Content -LiteralPath (Join-Path $root "config\live-report-catalog.json") -Raw | ConvertFrom-Json
if ($catalog.kind -ne "SreLiveReportAuthoringCatalog" -or $catalog.schemaVersion -ne 1 -or
    $catalog.automaticReportCreationImplemented -ne $false -or
    $catalog.automaticReportCreationImplemented -isnot [bool] -or
    $catalog.deploymentStatus -ne "AuthoringBlueprintsOnly") {
    throw "Catalog must identify its authoring-only deployment boundary."
}
if ($catalog.reports.Count -ne 2 -or @($catalog.reports.id | Select-Object -Unique).Count -ne 2) {
    throw "Expected two uniquely identified selected report blueprints."
}
function Assert-ReferencedFile {
    param([string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath)) { throw "Missing catalog file reference." }
    $path = Join-Path $root ($RelativePath.Replace("/", "\"))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing referenced file: $RelativePath" }
    return $path
}
Assert-ReferencedFile $catalog.documentation | Out-Null
if ($catalog.permissions.remediationTools -ne $false) { throw "Report blueprints must not enable remediation." }
foreach ($report in $catalog.reports) {
    $prompt = Get-Content -LiteralPath (Assert-ReferencedFile $report.promptFile) -Raw
    foreach ($file in @($report.queryFiles) + @($report.baselineFiles)) {
        Assert-ReferencedFile $file | Out-Null
    }
    if ($prompt -notmatch "<resolved-report-name>" -or $prompt -notmatch "read-only" -or
        $prompt -notmatch "NeedsReview" -or $prompt -notmatch "source|Source" -or
        $prompt -notmatch "Do not" -or $report.dataSources.Count -lt 1 -or
        $report.requiredChecks.Count -lt 6) {
        throw "Blueprint is missing naming, safety, classification or validation instructions."
    }
}
$software = $catalog.reports | Where-Object id -eq "third-party-software-update-tracker"
$fleet = $catalog.reports | Where-Object id -eq "arc-priority-lifecycle"
if ($software.sections.Count -ne 5 -or $fleet.sections.Count -ne 6) {
    throw "Selected report sections were not preserved."
}
$softwarePrompt = Get-Content -LiteralPath (Assert-ReferencedFile $software.promptFile) -Raw
if ($softwarePrompt -notmatch "155\.0\.8059\.40 versus approved 152\.0\.7977\.75 => AheadOfPolicy" -or
    $softwarePrompt -notmatch "approved target null => NeedsReview" -or
    $softwarePrompt -notmatch "partial" -or $softwarePrompt -notmatch "500-row") {
    throw "Software authoring instructions must preserve regression and partial-result requirements."
}
$query = Get-Content -LiteralPath (Assert-ReferencedFile $software.queryFiles[0]) -Raw
if ($query -notmatch 'let TargetMachines = dynamic\(\["<inventory-computer-name>"\]\)' -or
    $query -notmatch 'where Computer in~ \(TargetMachines\)' -or
    $query -notmatch 'arg_max\(TimeGenerated, \*\) by Computer, SoftwareName, Publisher, SoftwareType' -or
    $query -match "OUTDATED|152\.0\.7977|155\.0\.8059") {
    throw "Inventory query must be scoped, latest-observation-only and independent of captured target versions."
}
foreach ($property in $catalog.runtimeBindings.PSObject.Properties) {
    if ($property.Name -eq "plannedOfflineMachines") {
        if (@($property.Value).Count -ne 0) { throw "Public catalog must not inherit lab offline exceptions." }
    }
    else {
        foreach ($value in @($property.Value)) {
            if ([string]$value -notmatch "^<.+>$") { throw "Public scope binding must remain a placeholder: $($property.Name)" }
        }
    }
}
Write-Output "Live Report blueprint catalog, file references, sections, safety rules and scope placeholders passed. No report was created."
