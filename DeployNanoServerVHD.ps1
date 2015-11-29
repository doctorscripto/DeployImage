$Vhd='C:\Path\NanoVHD.Vhd'
$Size=20GB
$Wimfile='D:\Nanoserver\NanoServer.wim'
$SystemDrive='Y'
$OSDrive='Z'

New-VHD -Path $Vhd -SizeBytes $Size -Dynamic | Out-Null
Mount-VHD -Path $vhd | Out-Null
$Disk=Get-Vhd -Path $Vhd | Get-Disk

Clear-DiskStructure -Disk $disk
New-PartitionStructure -Disk $disk -MBR -SystemDrive $SystemDrive -OSDrive $OsDrive
Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\"
Send-BootCode -SystemDrive $SystemDrive -OSDrive $OSDrive

Dismount-VHD -Path $vhd

Remove-DriveLetter -Driveletter $SystemDrive
Remove-DriveLetter -Driveletter $OSdrive
