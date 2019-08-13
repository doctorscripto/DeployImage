function Convert-WIMtoVHD
{
[CmdletBinding()]
Param(
# Size of the VHD file
#
$Size=20GB,
# Obtain the default location of
# Virtual HardDisks in Hyper-V
#
$VHDPath='.\',
# Location of the WindowsImage (WIM)
# File to convert to VHD
#
$Wimfile='C:\Windows7\Install.wim',
# Netbios name of computer and VMName
#
$VM='Contoso-Win7',
# Index of Image in WIM file
#
$Index=1

)

If ($Vhdpath -eq '.\' -and (Get-Command Get-vmhost).count -ge 1)
    {
    $VHDPath=(Get-VMHost).VirtualHardDiskPath
    }

# Define VHD filename
#
$VHD="$VhdPath\$VM.vhd"
$OSDrive=(Get-NextActiveDriveLetter).DriveLetter
If ((Test-Path $VHD) -ne $false -or $OSDrive -eq 'None')
    {
        Return "Filename $VHD already exists or no available drive letter"
    }
Else
    {
    # Create a new VHD
    #
    $Result=New-VHD -Path $Vhd -SizeBytes $Size -Dynamic

    # Mount the VHD and identify it's Disk Object
    #
    $Result=Mount-VHD -Path $vhd
    $Disk=Get-Vhd -Path $Vhd | Get-Disk

    # Create a new Partition Structure of style
    # MBR, Format and Partition System and OSDrive
    #
    New-PartitionStructure -Disk $disk -MBR -BootDrive $OSDrive -OSDrive $OsDrive

    # Expand the Windows Image to the OSDrive
    #
    Expand-WindowsImage -imagepath "$wimfile" -index $Index -ApplyPath "$OSDrive`:\"

    # Send the Boot files to the Disk Structure
    #
    Send-BootCode -BootDrive $OSDrive -OSDrive $OSDrive
    # Dismount the Completed VHD
    #
    Dismount-VHD $VHD
    # Return path of VHD
    #
    Return $VHD
    }
}

Function Copy-WithProgress
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Source,
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Destination

    )
$Source=$Source.tolower()

$Filelist=get-childitem -path $source -Recurse
$Total=$Filelist.count
$Position=0
    foreach ($File in $Filelist)
    {
        $Filename=$File.Fullname.tolower().replace($Source,'')
        $DestinationFile=($Destination+$Filename).replace('\\','\')
        Write-Progress -Activity "Copying data from $source to $Destination" -Status "Copying Files" -PercentComplete (($Position/$total)*100)
        Copy-Item -path $File.FullName -Destination $DestinationFile
	$File.Fullname
	$DestinationFile
        $Position++
    }
}

<#
.Synopsis
   Copies supplied sample scripts from the DeployImage module
.DESCRIPTION
   Copy all sample PS1 files from DeployImage to the destination directory
.EXAMPLE
   Copies sample scripts to current directory

   Copy-DeployImageSample

.EXAMPLE
   Copies sample scripts to C:\Foo

   Copy-DeployImageSample -Destination C:\Foo


#>

Function Copy-DeployImageSample
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Destination='.\'

    )
$Modulepath=Split-path -path ((get-module -Name deployimage).path)
get-childitem -Path "$Modulepath\*.ps1" | copy-item -Destination $Destination
}

<#
.Synopsis
   Removes a Drive Letter from an assigned partition
.DESCRIPTION
   Removes a Drive Letter from an assigned partition
.EXAMPLE
   Remove L: from it's assigned partition, freeing it back to available drive letters

   Remove-DriveLetter -DriveLetter L
#>

Function Remove-DriveLetter
{
[CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$DriveLetter
    )

    Get-Volume -Drive $DriveLetter | Get-Partition | Remove-PartitionAccessPath -accesspath "$DriveLetter`:\"

	Do {
		$status=(Get-Volume -DriveLetter $DriveLetter -erroraction SilentlyContinue)
	   }
	until ($Status -eq $NULL)
}

<#
.Synopsis
   Builds an array of Drive Letters in use in Windows
.DESCRIPTION
   This will return an Array of Letters sorted that are presently in use in the Windows O/S
.EXAMPLE
   Get-ActiveDriveLetter
#>

Function Get-ActiveDriveLetter()
{

    Get-Volume | Where-Object { $_.DriveLetter } | Sort-object DriveLetter | Select-Object -ExpandProperty DriveLetter

}

<#
.Synopsis
   Tests if a Drive Letter is availale in Windows
.DESCRIPTION
   This will return a $TRUE if a Drive Letter is available to use in the Windows O/S
.EXAMPLE
   Test-ActiveDriveLetter
#>

Function Test-ActiveDriveLetter([String]$DriveLetter)
{

    (Get-ActiveDriveLetter).contains($DriveLetter)

}

<#
.Synopsis
   Provides the Next available Drive Letter for use in Windows
.DESCRIPTION
   This will the next letter available for use
.EXAMPLE
   Get-NextActiveDriveLetter
#>

Function Get-NextActiveDriveLetter()
{
   $Counter=67
    do
    {
        $DriveLetter=[char][byte]$Counter
        $Result=Test-ActiveDriveLetter -DriveLetter $DriveLetter
        $Counter++
    }
    until ($Result -eq $False -or $Counter -eq 91)

    If ($Result -eq $True)
    {
    [pscustomobject]@{'DriveLetter'='None'}
    }
    else
    {
    [pscustomobject]@{'DriveLetter'=$DriveLetter}
    }
}

<#
.Synopsis
   Identifies if the Operating System is 32bit or 64bit
.DESCRIPTION
   If the Operating system is 64bit, it will return the string " (x86)" to append to a "Program Files" path
.EXAMPLE
   $Folder="C:\Program Files$(Get-Architecture)"
#>

function Get-ArchitectureString
{
$Arch=(Get-CimInstance -Classname win32_operatingsystem).OSArchitecture
if ($Arch -eq '64-Bit')
    {
    Return [string]' (x86)'
    }

}

<#
.Synopsis
   Tests for the existence of the Windows 10 ADK
.DESCRIPTION
   This Cmdlet will return a Boolean True if the Windows 10 ADK is installed.  It depends upon the Get-ArchitectureString Cmdlet supplied within this module
.EXAMPLE
   $AdkInstalled = Test-WindowsADK
.EXAMPLE
   If (Test-WindowsADK -eq $TRUE)
    {
        Write-Output 'Windows 10 ADK is installed'
    }

#>

function Test-WindowsADK
{
(Test-Path -Path "C:\Program Files$(Get-ArchitectureString)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment")
}

function Get-AttachedDisk
{
[CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [switch]$USB,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [switch]$GUI
    )

If ($USB)
    {
        $DiskType='USB'
    }
    Else
    {
        $DiskType='SATA','SCSI','RAID'
    }


if ($GUI -and ((Get-CimInstance -Classname Win32_OperatingSystem).OperatingSystemSKU -ne 1))
    {
        Get-Disk | Where-Object { $DiskType -match $_.BusType } | Out-GridView -PassThru
    }
    Else
    {
        Get-Disk | Where-Object { $DiskType -match $_.BusType }
    }
}

<#
.Synopsis
   Erase the Partition structure on a Disk
.DESCRIPTION
   When provided with a Disk object from "Get-Disk" it will target and cleanly remove all partitions.  It addresses some of the limitations found with the Clear-Disk Cmdlet.
.EXAMPLE
   Erase partition structure on Disk Number 1

   $Disk=Get-Disk -Number 1
   Clear-DiskStructure -Disk $disk
.EXAMPLE
   Erase partition structure on all USB attached disks

   $DiskList=Get-Disk | Where { $_.BusType -eq 'USB'}
   Foreach ( $Disk in $Disklist )
   {
   Clear-DiskStructure -Disk $Disk
   }

#>

function Clear-DiskStructure
{
[CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Disk

    )
Get-Disk -Number ($Disk.number) | Get-Partition | Remove-partition -confirm:$false -erroraction SilentlyContinue
Clear-Disk -Number $Disk.Number -RemoveData -RemoveOEM -confirm:$false -ErrorAction SilentlyContinue
}

<#
.Synopsis
   Create a Partition structure, whether UEFI or MBR
.DESCRIPTION
   Creates a Partition structure when provided with a target disk from the GET-Disk Cmdlet including formatting and assigning drive letters.
.EXAMPLE
   Create a UEFI Partition structure on Disk 0, assign Drive Z: to the System Drive and Drive Y: to the OSDrive

   $Disk=Get-Disk -number 0
   New-PhysicalPartitionStructure -Disk $Disk -BootDrive Z -OSDrive Y

#>

function New-PartitionStructure
{
[CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Disk,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [switch]$MBR,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [switch]$USB,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=3)]
        [string]$BootDrive,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=4)]
        [string]$OSDrive

     )

    Clear-DiskStructure $Disk

    if ($MBR)
    {
    $Result=Initialize-Disk -Number $Disk.Number -PartitionStyle MBR -ErrorAction SilentlyContinue

            if ($USB)
            {
            $Partition=New-Partition -DiskNumber $Disk.Number  -UseMaximumSize -IsActive
            $Result=Format-Volume -Partition $Partition  -FileSystem FAT32 -NewFileSystemLabel 'Windows'
            $Partition | Add-PartitionAccessPath -AccessPath "$($OSDrive):\"


            }
            else
            {
            $Partition=New-Partition -DiskNumber $Disk.Number -UseMaximumSize -IsActive
            $Result=Format-Volume -Partition $Partition  -FileSystem NTFS -NewFileSystemLabel 'Windows'
            $Partition | Add-PartitionAccessPath -AccessPath "$($OSDrive):\"
            }

    }
    Else
    {
    $Result=Initialize-Disk -Number $Disk.Number -PartitionStyle GPT

    $Partition=New-Partition -DiskNumber $Disk.Number -Size 128MB ; # Create Microsoft Basic Partition
    $Result=Format-Volume -Partition $Partition -FileSystem Fat32 -NewFileSystemLabel 'MSR'
    $Result=Set-Partition -DiskNumber $Disk.Number -PartitionNumber $Partition.PartitionNumber -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'

    $Partition=New-Partition -DiskNumber $Disk.Number -Size 300MB ; # Create Microsoft Basic Partition and Set System as bootable
    $Result=Format-Volume -Partition $Partition  -FileSystem Fat32 -NewFileSystemLabel 'Boot'
    $Partition | Add-PartitionAccessPath -AccessPath "$($Bootdrive):\"

    $Result=Set-Partition -DiskNumber $Disk.Number -PartitionNumber $Partition.PartitionNumber

    $Partition=New-Partition -DiskNumber $Disk.Number -UseMaximumSize ; # Take remaining Disk space for Operating System
    $Result=Format-Volume -Partition $Partition  -FileSystem NTFS -NewFileSystemLabel 'Windows'
    $Partition | Add-PartitionAccessPath -AccessPath "$($OSDrive):\"

}

}


<#
.Synopsis
   Set San Policy for a Windows To Go key
.DESCRIPTION
   Creates and injects the necessary Disk policy which protects Windows to Go from Internal Drives.  Requires the drive letter of the target OSDrive.
.EXAMPLE
   Set Windows To Go key on Drive L with the proper San Policy

   Send-SanPolicy -OSDrive L
#>

Function Send-SanPolicy
{
[CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $OSDrive
     )

$SanPolicyXML=@"
<?xml version='1.0' encoding='utf-8' standalone='yes'?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="offlineServicing">
    <component
        xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        language="neutral"
        name="Microsoft-Windows-PartitionManager"
        processorArchitecture="x86"
        publicKeyToken="31bf3856ad364e35"
        versionScope="nonSxS"
        >
      <SanPolicy>4</SanPolicy>
    </component>
    <component
        xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        language="neutral"
        name="Microsoft-Windows-PartitionManager"
        processorArchitecture="amd64"
        publicKeyToken="31bf3856ad364e35"
        versionScope="nonSxS"
        >
      <SanPolicy>4</SanPolicy>
    </component>
  </settings>
</unattend>
"@

Add-content -path "$OSDrive`:\san-policy.xml" -Value $SanpolicyXML

Use-WindowsUnattend -UnattendPath "$OSDrive`:\san-policy.xml" -path "$OSdrive`:\" | Out-Null
}

<#
.Synopsis
   Creates an Unattend.XML file for injection into an O/S
.DESCRIPTION
   This Cmdlet will create an Unattend.XML file with suitable content.   Depending upon the provided parameters it can inject the needed content or credentials for a Domain Join or be left to join a Workgroup Configuration.
.EXAMPLE
   Create Unattend file for a computer named TestPC with all defaults for Password

   New-UnattendXMLContent -computername TestPC
.EXAMPLE


#>
function New-UnattendXMLContent
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$Computername,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$Timezone='Eastern Standard Time',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [string]$Owner='Nano Owner',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=3)]
        [string]$Organization='Nano Organization',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=4)]
        [string]$AdminPassword='P@ssw0rd',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=5,
                   ParameterSetName='DomainOnline')]
        [Switch]$Online,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=6,
                   ParameterSetName='DomainOnline')]
        [string]$DomainName,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=7,
                   ParameterSetName='DomainOnline')]
        [string]$DomainAccount,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=8,
                   ParameterSetName='DomainOnline')]
        [string]$DomainPassword,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=9,
                   ParameterSetName='DomainOnline')]
        [string]$DomainOU,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=10)]
        [string]$OfflineBlob,
                [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=11)]
        [switch]$SkipOOBE

     )

$UnattendXML=@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$Computername</ComputerName>
            <RegisteredOrganization>$Organization</RegisteredOrganization>
            <RegisteredOwner>$Owner</RegisteredOwner>
            <TimeZone>$Timezone</TimeZone>
        </component>
"@

If($JoinDomain -eq 'Online')
{
$UnattendXML=$UnattendXML+@"

        <component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
             <Identification>
                 <Credentials>
                     <Domain>$DomainName</Domain>
                     <Password>$Domainpassword</Password>
                     <Username>$Domainaccount</Username>
                 </Credentials>
                 <JoinDomain>$DomainName</JoinDomain>
                 <MachineObjectOU>$DomainOU</MachineObjectOU>
                 <UnsecureJoin>False</UnsecureJoin>
             </Identification>
         </component>
"@
}

if($Network)
{
$UnattendXML=$UnattendXML+@"
          <Interfaces>
                <Interface wcm:action="add">
                    <Ipv4Settings>
                        <DhcpEnabled>false</DhcpEnabled>
                    </Ipv4Settings>
                    <Identifier>Local Area Connection</Identifier>
                    <UnicastIpAddresses>
                        <IpAddress wcm:action="add" wcm:keyValue="1">$IPv4/$Mask</IpAddress>
                    </UnicastIpAddresses>
                    <Routes>
                        <Route wcm:action="add">
                            <Identifier>0</Identifier>
                            <Prefix>0.0.0.0/0</Prefix>
                            <Metric>20</Metric>
                            <NextHopAddress>$Gateway</NextHopAddress>
                        </Route>
                    </Routes>
                </Interface>
            </Interfaces>
"@
}

$UnattendXML=$UnattendXML+@"

    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$Adminpassword</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
	      <AutoLogon>
	            <Password>
	              <Value>$Adminpassword</Value>
	              <PlainText>true</PlainText>
	           </Password>
	        <Username>administrator</Username>
	        <LogonCount>1</LogonCount>
	        <Enabled>true</Enabled>
	      </AutoLogon>
         <RegisteredOrganization>$Organization</RegisteredOrganization>
            <RegisteredOwner>$Owner</RegisteredOwner>
"@

If ($SkipOOBE)
{
$UnattendXML=$UnattendXML+@"
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
        </component>
"@
}

$UnattendXML=$UnattendXML+@"

    </settings>
"@

If ($OfflineBlob)
{
$UnattendXML=$UnattendXML+@"

    <settings pass="offlineServicing">
        <component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OfflineIdentification>
                <Provisioning>
                    <AccountData>$OfflineBlob</AccountData>
                </Provisioning>
            </OfflineIdentification>
        </component>
    </settings>
"@
}


$UnattendXML=$UnattendXML+@"

    <cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
"@


Return $UnattendXML

}

Function Send-UnattendXML
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$OSDrive,
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$UnattendData
    )
        $Filename="$((Get-random).ToString()).xml"

        Remove-item -Path $Filename -force -ErrorAction SilentlyContinue
        New-Item -ItemType File -Path $Filename
        Add-Content -Path $Filename -Value $UnattendData
        Copy-Item -Path $filename -Destination "$OSDrive`:\Windows\System32\Sysprep\unattend.xml"
        Remove-item -Path $Filename -force -ErrorAction SilentlyContinue

}

function Send-BootCode
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$BootDrive,
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$OSDrive,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [switch]$USB

    )
    $oldpref=$ErrorActionPreference
    $ErrorActionPreference='SilentlyContinue'

    if ($USB)
    {
        & "$($env:windir)\system32\bootsect.exe" /nt60 "$OSDrive`:" > NULL
    }
    else
    {
    & "$($env:windir)\system32\bcdboot" "$OSDrive`:\Windows" /s "$BootDrive`:" /f ALL > NULL
    }
    $ErrorActionPreference=$oldpref
}


function New-WindowsPEWim
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $WinPETemp='C:\TempPE',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $Destination='C:\PeWim'

    )

    Begin
    {
    }

    Process
    {
        $Env:WinPERoot="C`:\Program Files$(Get-ArchitectureString)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"

        $WinADK="$($Env:WinPERoot)\amd64"

        Remove-item -Path $WinPETemp -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        New-Item -ItemType Directory -Path $WinPETemp -Force | Out-Null
        Copy-Item -Path "$WinAdk\Media" -Destination $WinPETemp -Recurse -Force | Out-Null
        New-Item -ItemType Directory -Path "$WinPETemp\Media\Sources" -Force | Out-Null
        Copy-Item -path "$WinAdk\en-us\winpe.wim" -Destination "$WinPETemp\Media\Sources\boot.wim" | Out-Null
        New-Item -ItemType Directory -Path "$WinPETemp\Mount" -Force | Out-Null

        Mount-WindowsImage -ImagePath "$WinPETemp\Media\Sources\boot.wim" -Index 1 -path "$WinPETemp\Mount" | Out-Null

        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-WMI.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-WMI_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-NetFx.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-NetFx_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-Scripting.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-Scripting_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-PowerShell.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-PowerShell_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-DismCmdlets.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-DismCmdlets_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-EnhancedStorage.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-EnhancedStorage_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-StorageWMI.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-StorageWMI_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck | Out-Null

        # Custom PowerShell Script to launch after Wpeinit.exe
        # This is hardcoded presently to automatically
        # Start the DeployImage module
        # from the WinPE media for Easy Server Deployment
        $PowerShellScript=@'
Set-ExecutionPolicy -executionpolicy Bypass
$USBDisk=(Get-Disk | Where-Object { $_.BusType -eq 'USB' -and '$_.IsActive' })
$DriveLetter=($USBDisk | Get-Partition).DriveLetter
Set-Location ($DriveLetter+':\DeployImage\')
Import-Module ($DriveLetter+':\DeployImage\DeployImage.Psd1')
'@

        # Carriage Return (Ascii13) and Linefeed (Ascii10)
        # the characters at the end of each line in a Here String
        $CRLF=[char][byte]13+[char][byte]10

        $PowerShellCommand=$PowerShellScript.replace($CRLF,';')

        $PowerShellStart='powershell.exe -executionpolicy bypass -noexit -command "'+$PowerShellCommand+'"'
        Add-Content -Path "$WinPEtemp\Mount\Windows\System32\Startnet.cmd" -Value $PowerShellStart

        Dismount-WindowsImage -path "$WinPETemp\Mount" -Save | Out-Null

        New-Item -Path $Destination -ItemType Directory -Force | Out-Null
        Copy-Item -path "$WinPETemp\Media\Sources\boot.wim" -destination "$Destination\" | Out-Null
        Remove-Item -Path "$Destination\Custom.wim" -erroraction SilentlyContinue | Out-Null
        Rename-Item -Path "$Destination\Boot.wim" -NewName 'Custom.wim' | Out-Null
        Remove-item -Path $WinPETemp -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        Return "$Destination\Custom.wim"

        }
    End
    {
    }
}
