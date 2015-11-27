$Wimfile='winpe.wim'
$OSDrive='Z'
$WinPEDrive='C'
$Disk
$DriverPath='C:\Dell'
$WinPETemp='C:\PETemp'

$Env:WinPERoot="$($WinPEDrive)`:\Program Files$(Get-ArchitectureString)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment" 
$WinADK="$($Env:WinPERoot)\amd64"

Remove-item -Path $WinPETemp -Recurse -Force
New-Item -ItemType Directory -Path $WinPETemp -Force
Copy-Item -Path "$WinAdk\Media" -Destination $WinPETemp -Recurse -Force
New-Item -ItemType Directory -Path "$WinPETemp\Media\Sources" -Force
Copy-Item -path "$WinAdk\en-us\winpe.wim" -Destination "$WinPETemp\Media\Sources\boot.wim"

if ($Wimfile -ne '')
{
Copy-Item -Path $Wimfile -Destination "$WinPETemp\Media\Sources\boot.wim"
}
        
New-USBPartitionStructure -Disk $disk -OSDrive $OSDrive -USB -GUI
$WinPEKey=$OsDrive+':'

Copy-Item -Path "$WinPETemp\Media\*" -destination "$WinPeKey\" -Recurse

Send-BootCode -OSDrive $OSDrive -USB

If ($DriverPath -ne $NULL)
{
    Add-WindowsDriver -Driver $DriverPath -Recurse -Path "$OSDrive`:\" -ErrorAction SilentlyContinue
}

Remove-DriveLetter -DriveLetter $OSDrive
 