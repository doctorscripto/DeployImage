$Wimfile='D:\Nanoserver\NanoServer.wim'
$BootDrive='Y'
$OSDrive='Z'

$Disk=Get-AttachedDisk
$DriverPath='C:\Dell'

Clear-DiskStructure -Disk $disk
New-PartitionStructure -Disk $disk -BootDrive $BootDrive -OSDrive $OsDrive
Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\"
Send-BootCode -BootDrive $BootDrive -OSDrive $OSDrive

If ($DriverPath -ne $NULL)
{
    Add-WindowsDriver -Driver $DriverPath -Recurse -Path "$OSDrive`:\" -ErrorAction SilentlyContinue
}

Remove-DriveLetter -Driveletter $BootDrive
Remove-DriveLetter -Driveletter $OSdrive
