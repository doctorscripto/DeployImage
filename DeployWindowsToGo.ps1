$Wimfile='C:\Sources\Install.wim'
$BootDrive='Y'
$OSDrive='Z'

$Disk=Get-AttachedDisk -GUI
$DriverPath='C:\Drivers'

New-PartitionStructure -Disk $disk -BootDrive $BootDrive -OSDrive $OsDrive
Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\"

$Unattendfile='C:\Foo\Unattend.xml'
$Content=New-UnattendXMLContent -computername WTGKey -TimeZone 'Eastern Standard Time'
Add-Content -path $Unattendfile -value $Content
Copy-Item $UnattendFile -destination "$OSDrive`:\Windows\System32\Sysprep" 
Send-BootCode -BootDrive $BootDrive -OSDrive $OSDrive
Send-SanPolicy -OSDrive $OSDrive

If ($DriverPath -ne $NULL)
{
    Add-WindowsDriver -Driver $DriverPath -Recurse -Path "$OSDrive`:\" -ErrorAction SilentlyContinue
}
