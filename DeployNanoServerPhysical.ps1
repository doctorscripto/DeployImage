    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $WinPEMedia
    )


$Wimfile=$WinPeMedia+':\Nanotemp\Nanocustom.wim'
$BootDrive='Y'
$OSDrive='Z'

$Disk=Get-AttachedDisk
$DriverPath=$WinPEMedia+':\Drivers'

New-PartitionStructure -Disk $disk -BootDrive $BootDrive -OSDrive $OsDrive
Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\"

$Unattendfile='C:\Foo\Unattend.xml'
$Content=New-UnattendXMLContent -computername NanoServer1 -TimeZone 'Eastern Standard Time'
Add-Content -path $Unattendfile -value $Content
Copy-Item $UnattendFile -destination "$OSDrive`:\Windows\System32\Sysprep" 
Send-BootCode -BootDrive $BootDrive -OSDrive $OSDrive

If ($DriverPath -ne $NULL)
{
    Add-WindowsDriver -Driver $DriverPath -Recurse -Path "$OSDrive`:\" -ErrorAction SilentlyContinue
}
