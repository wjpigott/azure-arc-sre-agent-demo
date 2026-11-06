# Readable snapshot of chromezip 157.8103.2's published install action.
# Keep behavior identical to config\chromezip-tested-commands.json.
Expand-Archive -LiteralPath ChromeSetup.zip -DestinationPath chrome_x -Force
$e = (Get-ChildItem chrome_x -Recurse -Filter *.exe | Select-Object -First 1).FullName
if (-not $e) { throw 'Installer exe not found in zip' }
$p = Start-Process $e -ArgumentList '/silent','/install' -PassThru
$p.WaitForExit()
$c = Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'
$d = (Get-Date).AddMinutes(10)
while (-not (Test-Path $c) -and (Get-Date) -lt $d) { Start-Sleep 5 }
if (-not (Test-Path $c)) { throw 'Chrome not installed - ChromeSetup.exe needs internet access from the VM' }
exit 0
