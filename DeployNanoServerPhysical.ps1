$Wimfile='D:\Nanoserver\NanoServer.wim'
$SystemDrive='Y'
$OSDrive='Z'

$Disk=Get-AttachedDisk -GUI
$DriverPath='C:\Dell'

Clear-DiskStructure -Disk $disk
New-PartitionStructure -Disk $disk -SystemDrive $SystemDrive -OSDrive $OsDrive
Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\"
Send-BootCode -SystemDrive $SystemDrive -OSDrive $OSDrive

If ($DriverPath -ne $NULL)
{
    Add-WindowsDriver -Driver $DriverPath -Recurse -Path "$OSDrive`:\" -ErrorAction SilentlyContinue
}

Remove-DriveLetter -Driveletter $SystemDrive
Remove-DriveLetter -Driveletter $OSdrive
