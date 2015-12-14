# New-NanoServerMedia
$OSdrive='L'
$WinPETemp='C:\TempPE'
$Wimfile='C:\Pewim\custom.wim'
$DriverPath='C:\Drivers'
$NanoMedia='C:\'
$WinPeDrive='C'

$Wimfile=New-WindowsPEWim
$CustomNano=New-NanoServerWIM -Mediapath C:\ -Destination C:\NanoTemp -Compute

$Disk=Get-AttachedDisk -USB -GUI
$Env:WinPERoot="$($WinPEDrive)`:\Program Files$(Get-ArchitectureString)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment" 
$WinADK="$($Env:WinPERoot)\amd64"

Remove-item -Path $WinPETemp -Recurse -Force
New-Item -ItemType Directory -Path $WinPETemp -Force
Copy-Item -Path "$WinAdk\Media" -Destination $WinPETemp -Recurse -Force
New-Item -ItemType Directory -Path "$WinPETemp\Media\Sources" -Force
Copy-Item -path "$WinAdk\en-us\winpe.wim" -Destination "$WinPETemp\Media\Sources\boot.wim"

if ($Wimfile -ne $NULL)
{
Copy-Item -Path $Wimfile -Destination "$WinPETemp\Media\Sources\boot.wim"
}
        
New-PartitionStructure -Disk $disk -OSDrive $OSDrive -USB -MBR
$WinPEKey=$OsDrive+':'

Copy-Item -Path "$WinPETemp\Media\*" -destination "$WinPeKey\" -Recurse

Send-BootCode -OSDrive $OSDrive -USB

$Modulepath=Split-path ((get-module deployimage).path)

New-Item -Path "$WinPeKey\DeployImage" -ItemType Directory -Force
Copy-Item -Path "$ModulePath\*" -Destination "$WinPEkey\DeployImage" -Recurse
   
If ($DriverPath -ne $NULL -and (Test-Path $DriverPath))
{
New-Item -Path "$WinPEKey\Drivers" -ItemType Directory -Force
Copy-Item -Path "$DriverPath\*" -Destination "$WinPEkey\Drivers" -Recurse
}
    
New-Item -Path "$WinPeKey\NanoServer" -ItemType Directory -Force
Copy-Item -Path "$($NanoMedia)NanoServer\*" -Destination "$WinPEKey\NanoServer\" -Recurse
Copy-Item -Path $CustomNano -Destination "$WinPeKey\NanoServer"

Remove-DriveLetter -DriveLetter $OSdrive
