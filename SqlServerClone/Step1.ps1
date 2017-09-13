[System.Net.Dns]::GetHostAddresses($env:computername) | 
	where AddressFamily -eq "InterNetwork" | 
	foreach { Add-Content -Encoding UTF8 "$($env:windir)\system32\Drivers\etc\hosts" "$($_.IPAddressToString) msbivser001" }
$drive = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'E:'"
Set-WmiInstance -input $drive -Arguments @{DriveLetter="F:"}
$RunOnceKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
$PsExe = "C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe"
Set-ItemProperty $RunOnceKey "NextRun" ("$($PsExe) -executionPolicy Unrestricted -File $($PSScriptRoot)\Step2.ps1")
Restart-Computer -Force
