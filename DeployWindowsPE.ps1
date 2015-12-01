$Wimfile='C:\Pewim\custom.wim'
$OSDrive='L'
$WinPEDrive='C'
$Disk
$DriverPath='C:\Dell'
$WinPETemp='C:\TempPE'

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

Remove-DriveLetter -DriveLetter $OSDrive
