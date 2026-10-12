# Stage Approved Package Runbook

## Purpose

`runbooks/Stage-ApprovedPackage.ps1` stages one approved third-party installer
from the approved package catalog to a controlled local directory.

It runs on the `SRE-Package-Staging` Hybrid Worker on `<package-staging-worker>`:

| Item | Value |
| --- | --- |
| Local staging root | `<local-staging-root>` |
| Automation account | `SRE-Package-Staging` |
| Hybrid worker group | `SRE-Package-Staging` |
| Execution identity | `NT AUTHORITY\SYSTEM` |

The runbook does not install packages, modify target machines, or send notifications.

## Controls enforced

The runbook refuses to stage a package unless the catalog entry:

- Exists and uniquely matches `ProductName`.
- Has `stagingStatus` set to `ApprovedForStaging`.
- Has an approved version, release-note URL, HTTPS download URL, SHA-256, verification method, and staging path.
- Uses a 64-character SHA-256 value.
- Targets a relative subdirectory of the approved local staging root.

It downloads into a temporary local directory, validates SHA-256, validates Authenticode for Windows installer formats, validates the expected signer when specified, moves the verified package to `<local-staging-root>`, and writes a JSON staging receipt beside it.

## Publish the runbook

1. In **Automation Accounts** > **SRE-Package-Staging** > **Runbooks**, create a **PowerShell** runbook named `Stage-ApprovedPackage`.
2. Set the runtime to **PowerShell 5.1**.
3. Copy the contents of `runbooks/Stage-ApprovedPackage.ps1` into the editor.
4. Save, test with the Hybrid Worker group, then publish.
5. Run jobs only on **Hybrid Worker** > `SRE-Package-Staging`.

## Make the catalog available

Copy the reviewed manifest to the Hyper-V host:

```text
<local-staging-root>\control\approved-versions.json
```

The runbook reads this local path. It intentionally does not use a browser download, a user profile folder, or an untrusted request URL.

## Approve one package

For the selected product only, update its catalog entry after a change owner validates the exact artifact. A vendor-published SHA-256 is preferred. For signed Windows installers without one, use an approved SHA-256 captured in a controlled review and the expected Authenticode signer.

```json
{
  "approvedVersion": "verified-version",
  "downloadUrl": "https://vendor.example/version-pinned-installer.msi",
  "sha256": "APPROVED_64_CHARACTER_SHA256",
  "artifactVerificationMethod": "VendorPublishedSha256",
  "expectedSignerSubject": "CN=Expected Publisher, O=Expected Publisher, C=US",
  "stagingStatus": "ApprovedForStaging",
  "stagingBlocker": null,
  "stagingRelativePath": "product\\verified-version"
}
```

### Capture approval evidence

On a controlled administrative machine or the Hybrid Worker, capture the proposed evidence:

```powershell
.\scripts\Get-ArtifactApprovalEvidence.ps1 `
  -DownloadUrl "https://vendor.example/version-pinned-installer.msi" `
  -FileName "installer.msi"
```

The command follows up to five HTTPS redirects and only produces review evidence; it does not stage, install, or approve the package. Confirm the URL, SHA-256, `signatureStatus`, and signer identity against the change before adding the SHA-256 to the catalog.

## Start a staging job

Use a meaningful approval or change ID:

```text
ProductName: 7-Zip
ApprovalId: CHG-000001
```

Configure the Automation job with fixed `CatalogPath` and `StagingRoot` values.
Do not expose these parameters to SRE Agent or allow an agent request to
override them; only `ProductName` and `ApprovalId` should be supplied per
approved job.

Expected successful status: `StagedVerified`.

The receipt and staged package are written under the product/version directory specified by the catalog, for example:

```text
<local-staging-root>\7zip\<version>\
```

## First test

Do not bypass the catalog controls. The first successful test must use:

1. One noncritical package.
2. A version-pinned vendor artifact.
3. A vendor-published SHA-256, or an approved SHA-256 plus a valid expected Authenticode signer.
4. An explicit change approval ID.

After a successful stage, preview—not send—the notification using the template in `software-remediation-staging.md`.
