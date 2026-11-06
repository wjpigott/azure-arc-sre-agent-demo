# Readable snapshot of chromezip 157.8103.2's published remove action.
# Keep behavior identical to config\chromezip-tested-commands.json.
$c = Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'
if (-not (Test-Path $c)) { exit 0 }
Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force
$k = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue |
    Get-ItemProperty | Where-Object { $_.DisplayName -eq 'Google Chrome' } | Select-Object -First 1
if ($k -and $k.PSChildName -like '{*}') {
    Start-Process msiexec.exe -ArgumentList '/x',$k.PSChildName,'/qn','/norestart' -Wait
}
else {
    $s = (Get-ChildItem (Join-Path $env:ProgramFiles 'Google\Chrome\Application\*\Installer\setup.exe') | Select-Object -First 1).FullName
    if ($s) {
        $p = Start-Process $s -ArgumentList '--uninstall','--system-level','--force-uninstall' -PassThru
        $p.WaitForExit()
    }
}
$d = (Get-Date).AddMinutes(5)
while ((Test-Path $c) -and (Get-Date) -lt $d) { Start-Sleep 3 }
if (Test-Path $c) { throw 'Chrome still present after uninstall' }
exit 0
