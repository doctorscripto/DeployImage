    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $WinPEMedia
    )


$Wimfile=$WinPeMedia+':\Nanoserver\NanoServer.wim'
$BootDrive='Y'
$OSDrive='Z'

$Disk=Get-AttachedDisk
$DriverPath=$WinPEMedia+':\Drivers'

Clear-DiskStructure -Disk $disk
New-PartitionStructure -Disk $disk -BootDrive $BootDrive -OSDrive $OsDrive
Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\"
Send-BootCode -BootDrive $BootDrive -OSDrive $OSDrive

If ($DriverPath -ne $NULL)
{
    Add-WindowsDriver -Driver $DriverPath -Recurse -Path "$OSDrive`:\" -ErrorAction SilentlyContinue
}
