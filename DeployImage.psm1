<#
.Synopsis
   Identifies if the Operating System is 32bit or 64bit 
.DESCRIPTION
   If the Operating system is 64bit, it will return the string " (x86)" to append to a "Program Files" path
.EXAMPLE
   $Folder="C:\Program Files$(Get-Architecture)"
#>

function Get-Architecture
{
$Arch=(Get-CimInstance win32_operatingsystem).OSArchitecture
if ($Arch='32-Bit')
    {
    Return [string]' (x86)'
    }

}

<#
.Synopsis
   Tests for the existence of the Windows 10 ADK
.DESCRIPTION
   This Cmdlet will return a Boolean True if the Windows 10 ADK is installed.  It depends upon the Get-Architecture Cmdlet supplied within this module
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
(Test-Path "C:\Program Files$(Get-Architecture)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment") 
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
        $DiskType='SATA','SCSI'
    }


if ($GUI)
    {
        Get-Disk | Where { $DiskType -match $_.BusType } | Out-GridView -PassThru
    }
    Else
    {
        Get-Disk | Where { $DiskType -match $_.BusType } 
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
   Create a UEFI Partition structure
.DESCRIPTION
   Creates a UEFI Partition structure when provided with a target disk from the GET-Disk Cmdlet including formatting and assigning drive letters.
.EXAMPLE
   Create a UEFI Partition structure on Disk 0, assign Drive Z: to the System Drive and Drive Y: to the OSDrive

   $Disk=Get-Disk -number 0
   New-PhysicalPartitionStructure -Disk $Disk -SystemDrive Z -OSDrive Y
   
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
        [switch]$NTFS,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=3)]
        [string]$SystemDrive,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=4)]
        [string]$OSDrive
                
     )

    Clear-DiskStructure $Disk
    
    if ($MBR)
    {
    $FileSystem='FAT32'
        if ($NTFS)
            {
            $Filesystem='NTFS'
            }
    
        Initialize-Disk -Number $Disk.Number -PartitionStyle MBR -ErrorAction SilentlyContinue
        $Partition=New-Partition -DiskNumber $Disk.Number -DriveLetter $OSDrive -UseMaximumSize -IsActive ; # Take remaining Disk space for Operating System

        Format-Volume -Partition $Partition  -FileSystem $Filesystem -NewFileSystemLabel 'Windows'
    
    }
    Else
    {
    Initialize-Disk -Number $Disk.Number -PartitionStyle GPT

    $Partition=New-Partition -DiskNumber $Disk.Number -Size 128MB ; # Create Microsoft Basic Partition
    Format-Volume -Partition $Partition -FileSystem Fat32 -NewFileSystemLabel 'MSR'
    Set-Partition -DiskNumber $Disk.Number -PartitionNumber $Partition.PartitionNumber -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'

    $Partition=New-Partition -DiskNumber $Disk.Number -Size 300MB -DriveLetter $SystemDrive ; # Create Microsoft Basic Partition and Set System as bootable
    Format-Volume -Partition $Partition  -FileSystem Fat32 -NewFileSystemLabel 'System'
    Set-Partition -DiskNumber $Disk.Number -PartitionNumber $Partition.PartitionNumber -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'

    $Partition=New-Partition -DiskNumber $Disk.Number -DriveLetter $OSDrive -UseMaximumSize ; # Take remaining Disk space for Operating System
    Format-Volume -Partition $Partition  -FileSystem NTFS -NewFileSystemLabel 'Windows'
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

Use-WindowsUnattend –unattendpath "$OSDrive`:\san-policy.xml" –path "$OSdrive`:\" | Out-Null
}

<#
.Synopsis
   Creates an Unattend.XML file for injection into an O/S
.DESCRIPTION
   This Cmdlet will create an Unattend.XML file with suitable content.   Depending upon the provided parameters it can inject the needed content or credentials for a Domain Join or be left to join a Workgroup Configuration.
.EXAMPLE
   Create Unattend file for a computer named TestPC with all defaults for Password
    
   New-Unattend -computername TestPC
.EXAMPLE


#>
function New-Unattend
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
                   Position=5)]
        [switch]$JoinDomain,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=6,
                   ParameterSetName='Domain')]
        [string]$DomainName,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=7,
                   ParameterSetName='Domain')]
        [string]$DomainAccount,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=8,
                   ParameterSetName='Domain')]
        [string]$DomainPassword,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=9,
                   ParameterSetName='Domain')]
        [string]$DomainOU
                
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

If($JoinDomain)
{
$UnattendXML=$UnattendXML+@"
    
        <component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmln:xsi="http://www.w3.org/2001/XMLSchema-instance">
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
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
        </component>
    </settings>
    <cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
"@

Return $UnattendXML

}

Function Send-Unattend
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
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$SystemDrive,
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$OSDrive,
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [string]$USB
    
    )
    if ($USB)
    {
        & "$($env:windir)\system32\bootsect.exe" /nt60 "$OSDrive`:"
    }
    else
    {
        & "$($env:windir)\system32\bcdboot" "$SystemDrive`:\Windows" /s "$OSDrive`:"  /f ALL
    }
}

function New-VirtualDiskForImage
{
[CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [System.String]$Vhd,
        [Parameter(Mandatory=$False,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [System.Int64]$Size=20GB
    )
       New-VHD -Path $Vhd -SizeBytes $Size -Dynamic | Out-Null
       Mount-VHD -Path $vhd | Out-Null
       $Disk=Get-Vhd -Path $Vhd | Get-Disk
       Return $Disk
}

<#
.Synopsis
   Create a new Nano Server VM
.DESCRIPTION
   Long description
.EXAMPLE
   New-NanoServer -computername NanoServer1

   Creates a new Virtual Machine in Hyper-V which is running a Nano Server named 'NanoServer1'
#>
function New-NanoServerWIM
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$Mediapath,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $SetupComplete,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $Destination='.\NanoTemp'

     )

    Begin
    {
    }
 
    Process
    {
        Remove-Item $Destination -Force -Recurse -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $Destination -Force
        New-Item -ItemType Directory -Path "$Destination\Mount" -Force

        Copy-Item -Path "$($MediaPath)NanoServer\Nanoserver.wim" -Destination $Destination
        Set-ItemProperty "$Destination\Nanoserver.wim" -Name IsReadOnly -Value $False
        
        Mount-WindowsImage -ImagePath "$Destination\Mount\Nanoserver.wim" -Index 1 -path "$Destination\Mount"
        
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-Guest-Package.cab" -Path "$Destination\Mount\"
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-Compute-Package.cab" -Path "$Destination\Mount\"
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-OEM-Drivers-Package.cab" -Path "$Destination\Mount\"
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-Guest-Package.cab" -Path "$Destination\Mount\"
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-Compute-Package.cab" -Path "$Destination\Mount\"
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-Defender-Package.cab" -Path "$Destination\Mount\"
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-OEM-Drivers-Package.cab" -Path "$Destination\Mount\"
        
        New-Item -Path "$Destination\Mount\Windows\Setup\Scripts" -Force -ItemType Directory
        New-Item -Path "$Destination\Mount\Windows\Setup\Scripts\SetupComplete.cmd" -Value $SetupComplete -Force -ItemType File
    }     
End
        {
        }
}

function New-WindowsToGo
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
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=5)]
        [switch]$JoinDomain,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=6,
                   ParameterSetName='Domain')]
        [string]$DomainName,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=7,
                   ParameterSetName='Domain')]
        [string]$DomainAccount,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=8,
                   ParameterSetName='Domain')]
        [string]$DomainPassword,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=9,
                   ParameterSetName='Domain')]
        [string]$DomainOU,
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=10,
                   ParameterSetName='Domain')]
        [string]$Wimfile,
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$SystemDrive='Y',
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$OSDrive='Z',
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        $Disk,     
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        $DriverPath
        )

    Begin
    {
    }
 
    Process
    {

        New-PhysicalPartitionStructure -Disk $disk -SystemDrive -OSDrive $OSDrive
        Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\" -LogPath "$($Env:temp)\Dism$((Get-Date -Format 'MMddyyyyhhmmssmm').tostring()).log"
        
        Send-BootCode -SystemDrive $SystemDrive -OSDrive $OSDrive
        
        Send-SanPolicy -OSDrive $OSDrive
        
        $UnattendXML=New-Unattend -Computername $computername -Timezone $Timezone -Owner $Owner -Organization $Organization -AdminPassword $AdminPassword -Domain $DomainName -DomainAccount $DomainAccount -DomainPassword $DomainPassword -DomainOU $DomainOU
        
        Send-Unattend -OSDrive $OSDrive -UnattendData $UnattendXML

        If ($DriverPath -ne $NULL)
        {
        Add-WindowsDriver -Driver $DriverPath -Recurse -Path "$OSDrive`:\" -ErrorAction SilentlyContinue
        }

        }
End
        {
        }
}
function New-WindowsPE
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$Wimfile='winpe.wim',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$OSDrive='Z',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$WinPEDrive='C',
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        $Disk,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $DriverPath,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $WinPETemp='C:\PETemp'

     )

    Begin
    {
    }
 
    Process
    {
        $Env:WinPERoot="$($WinPEDrive)`:\Program Files$(Get-Architecture)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment" 

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
        
        New-USBPartitionStructure -Disk $disk -OSDrive $OSDrive

        $WinPEKey=$OsDrive+':'
	    Copy-Item -Path "$WinPETemp\Media\*" -destination "$WinPeKey\" -Recurse
        
        Send-USBBootCode -OSDrive $OSDrive

        If ($DriverPath -ne $NULL)
        {
        Add-WindowsDriver -Driver $DriverPath -Recurse -Path "$OSDrive`:\" -ErrorAction SilentlyContinue
        }

        }
End
        {
        }
}

function New-WindowsPEWim
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$Wimfile='winpe.wim',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$WinPEDrive='C',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $WinPETemp='C:\PETemp',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $Destination='.\'


     )

    Begin
    {
    }
 
    Process
    {
        $Env:WinPERoot="$($WinPEDrive)`:\Program Files$(Get-Architecture)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment" 

        $WinADK="$($Env:WinPERoot)\amd64"

        Remove-item -Path $WinPETemp -Recurse -Force
        
        New-Item -ItemType Directory -Path $WinPETemp -Force
                
        Copy-Item -Path "$WinAdk\Media" -Destination $WinPETemp -Recurse -Force

        New-Item -ItemType Directory -Path "$WinPETemp\Media\Sources" -Force
        
        Copy-Item -path "$WinAdk\en-us\$Wimfile" -Destination "$WinPETemp\Media\Sources\boot.wim"
        
        New-Item -ItemType Directory -Path "$WinPETemp\Mount" -Force

        Mount-WindowsImage -ImagePath "$WinPETemp\Media\Sources\boot.wim" -Index 1 -path "$WinPETemp\Mount"
        
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-WMI.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-WMI_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-NetFx.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-NetFx_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-Scripting.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-Scripting_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-PowerShell.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-PowerShell_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-DismCmdlets.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-DismCmdlets_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-EnhancedStorage.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-EnhancedStorage_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\WinPE-StorageWMI.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        Add-WindowsPackage -PackagePath "$($WinAdk)\Winpe_OCS\en-us\WinPE-StorageWMI_en-us.cab" -Path "$WinPeTemp\Mount" -IgnoreCheck
        
        Dismount-WindowsImage -path "$WinPETemp\Mount" -Save
        
        Copy-Item -path "$WinPETemp\Media\Sources\boot.wim" -destination "$Destination\Custom.wim"
        }
    End
    {
    }
}

Export-ModuleMember -Function *

