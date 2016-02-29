# New-NanoServerMedia
$OSdrive='L'
$WinPETemp='C:\TempPE'
$Wimfile='C:\Pewim\custom.wim'
$DriverPath='C:\Drivers'
$NanoMedia='C:\'
$WinPeDrive='C'

#$Wimfile=New-WindowsPEWim
$WimFile='C:\PeWim\Custom.wim'

#$CustomNano=New-NanoServerWIM -Mediapath C:\ -Destination C:\NanoTemp -Compute
$CustomNano='C:\NanoTemp\NanoCustom.wim'

$Disk=Get-AttachedDisk -USB -GUI
$Env:WinPERoot="$($WinPEDrive)`:\Program Files$(Get-ArchitectureString)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment" 
$WinADK="$($Env:WinPERoot)\amd64"

$Result=Remove-item -Path $WinPETemp -Recurse -Force -ErrorAction SilentlyContinue
$Result=New-Item -ItemType Directory -Path $WinPETemp -Force
$Result=Copy-Item -Path "$WinAdk\Media" -Destination $WinPETemp -Recurse -Force
$Result=New-Item -ItemType Directory -Path "$WinPETemp\Media\Sources" -Force
$Result=Copy-Item -path "$WinAdk\en-us\winpe.wim" -Destination "$WinPETemp\Media\Sources\boot.wim"

if ($Wimfile -ne $NULL)
{
Copy-Item -Path $Wimfile -Destination "$WinPETemp\Media\Sources\boot.wim"
}
        
New-PartitionStructure -Disk $disk -OSDrive $OSDrive -USB -MBR
$WinPEKey=$OsDrive+':'

$Result=Copy-Item -Path "$WinPETemp\Media\*" -destination "$WinPeKey\" -Recurse

Send-BootCode -OSDrive $OSDrive -USB

$Modulepath=Split-path ((get-module deployimage).path)

$Result=New-Item -Path "$WinPeKey\DeployImage" -ItemType Directory -Force
$Result=Copy-Item -Path "$ModulePath\*" -Destination "$WinPEkey\DeployImage" -Recurse
   
If ($DriverPath -ne $NULL -and (Test-Path $DriverPath))
{
$Result=New-Item -Path "$WinPEKey\Drivers" -ItemType Directory -Force
$Result=Copy-Item -Path "$DriverPath\*" -Destination "$WinPEkey\Drivers" -Recurse
}
    
$Result=New-Item -Path "$WinPeKey\NanoServer" -ItemType Directory -Force
$Result=Copy-Item -Path "$($NanoMedia)NanoServer\*" -Destination "$WinPEKey\NanoServer\" -Recurse
$Result=Copy-Item -Path $CustomNano -Destination "$WinPeKey\NanoServer"

Remove-DriveLetter -DriveLetter $OSdrive
