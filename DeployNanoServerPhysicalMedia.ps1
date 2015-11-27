# New-NanoServerMedia
$Disk=Get-AttachedDisk -USB -GUI
$OSdrive='Z'
$WinPETemp='C:\WindowsPE'
$WimFile='C:\WinPECustom\Custom.wim'
$DriverPath='C:\Dell'
$NanoMedia='D:\'

New-NanoServerWIM -Mediapath $NanoMedia -Destination $NanoTemp
New-WindowsPE -OSDrive $OSDrive -Disk $Disk -WinPETemp $WinPETemp -Wimfile $WimFile

$Modulepath=Split-path ((get-module deployimage).path)

$WinPEkey=$OSDrive+':'

New-Item -Path "$WinPeKey\DeployImage" -ItemType Directory -Force
Copy-Item -Path "$ModulePath\*" -Destination "$WinPEkey\DeployImage" -Recurse
   
If ($DriverPath -ne $NULL -and (Test-Path $DriverPath))
{
New-Item -Path "$WinPEKey\Drivers" -ItemType Directory -Force
Copy-Item -Path "$DriverPath\*" -Destination "$WinPEkey\Drivers" -Recurse
}
    
New-Item -Path "$WinPeKey\NanoServer" -ItemType Directory -Force
Copy-Item -Path "$($NanoMedia)NanoServer\*" -Destination "$WinPEKey\NanoServer\" -Recurse
