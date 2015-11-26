# New-NanoServerMedia - sample script

$OSdrive='L'
$Disk=Get-USBDisk
#New-WindowsPEWim -Destination C:\MVP
New-WindowsPE -OSDrive L -Disk $Disk -WinPETemp 'C:\WindowsPE' -Wimfile C:\mvp\custom.wim
$Modulepath=Split-path ((get-module deployimage).path)
$WinPEkey=$OSDrive+':'
$NanoDrive='C'    

New-Item -Path "$WinPeKey\DeployImage" -ItemType Directory -Force
Copy-Item -Path "$ModulePath\*" -Destination "$WinPEkey\DeployImage" -Recurse
    
If ($DriverPath -ne $NULL -and (Test-Path $DriverPath))
{
New-Item -Path "$WinPEKey\Drivers" -ItemType Directory -Force
Copy-Item -Path "$DriverPath\*" -Destination "$WinPEkey\Drivers" -Recurse
}
    
New-Item -Path "$WinPeKey\NanoServer" -ItemType Directory -Force
Copy-Item -Path "$NanoDrive`:\NanoServer\*" -Destination "$WinPEKey\NanoServer\" -Recurse
