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

$Filelist=get-childitem $source -Recurse
$Total=$Filelist.count
$Position=0
    foreach ($File in $Filelist)
    { 
        $Filename=$File.Fullname.tolower().replace($Source,'') 
        $DestinationFile=($Destination+$Filename).replace('\\','\')
        Write-Progress -Activity "Copying data from $source to $Destination" -Status "Copying Files" -PercentComplete (($Position/$total)*100)
        Copy-Item $File.FullName -Destination $DestinationFile
        $Position++
    }
}

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
    Initialize-Disk -Number $Disk.Number -PartitionStyle MBR -ErrorAction SilentlyContinue
        
            if ($USB)
            {
            $Partition=New-Partition -DiskNumber $Disk.Number -DriveLetter $OSDrive -UseMaximumSize -IsActive
            Format-Volume -Partition $Partition  -FileSystem FAT32 -NewFileSystemLabel 'Windows'
            }
            else
            {
            $BootPartition = New-Partition –InputObject $Disk -Size (350MB) -IsActive 
            Format-Volume -NewFileSystemLabel "Boot" -FileSystem FAT32 -Partition $BootPartition -confirm:$False
            Set-Partition -InputObject $BootPartition -NewDriveLetter $BootDrive

            $OSPartition = New-Partition –InputObject $Disk -UseMaximumSize
            Format-Volume -NewFileSystemLabel "Windows" -FileSystem NTFS -Partition $OSPartition -confirm:$False
            Set-Partition -InputObject $OSPartition -NewDriveLetter $OSDrive
            }
    
    }
    Else
    {
    Initialize-Disk -Number $Disk.Number -PartitionStyle GPT

    $Partition=New-Partition -DiskNumber $Disk.Number -Size 128MB ; # Create Microsoft Basic Partition
    Format-Volume -Partition $Partition -FileSystem Fat32 -NewFileSystemLabel 'MSR'
    Set-Partition -DiskNumber $Disk.Number -PartitionNumber $Partition.PartitionNumber -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'

    $Partition=New-Partition -DiskNumber $Disk.Number -Size 300MB -DriveLetter $BootDrive ; # Create Microsoft Basic Partition and Set System as bootable
    Format-Volume -Partition $Partition  -FileSystem Fat32 -NewFileSystemLabel 'Boot'
    Set-Partition -DiskNumber $Disk.Number -PartitionNumber $Partition.PartitionNumber

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
    if ($USB)
    {
        & "$($env:windir)\system32\bootsect.exe" /nt60 "$OSDrive`:"
    }
    else
    {
    & "$($env:windir)\system32\bcdboot" "$OSDrive`:\Windows" /s "$BootDrive`:" /f ALL
    }
}

function New-NanoServerWIM

{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$Mediapath,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$Destination='C:\NanoTemp',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [switch]$Compute=$True,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=3)]
        [switch]$Clustering=$True,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=4)]
        [switch]$GuestDrivers=$True,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=5)]
        [switch]$OEMDrivers=$True,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=6)]
        [switch]$Storage=$False,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=7)]
        [switch]$Defender=$True,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=8)]
        [switch]$ReverseForwarders=$False,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=9)]
        [switch]$DNS=$False,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=10)]
        [switch]$DSC=$True,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=11)]
        [switch]$IIS=$False,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=12)]
        [switch]$SCVMM=$False,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=13)]
        [switch]$NPDS=$False,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=14)]
        [switch]$DCB=$False

     )

    Begin
    {
    }
 
    Process
    { 
        Remove-Item -Path $Destination -Force -Recurse -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        New-Item -ItemType Directory -Path "$Destination\Mount" -Force | Out-Null

        Copy-Item -Path "$($MediaPath)NanoServer\Nanoserver.wim" -Destination $Destination | Out-Null
        Set-ItemProperty -Path "$($Destination)\Nanoserver.wim" -Name IsReadOnly -Value $False | Out-Null
        
        Mount-WindowsImage -ImagePath "$Destination\Nanoserver.wim" -Index 1 -path "$Destination\Mount"| Out-Null
        
        If ($Compute) # Hyper-V Role
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-Compute-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-Compute-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }

        If ($Containers) # Windows Containers
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-Containers-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-Containers-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }
        If ($DCB) # Data Center Bridging
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-DCB-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-DCB-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }
        If ($Defender) # Windows Defender
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-Defender-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-Defender-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }
        If ($DNS) # DNS Server
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-DNS-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-DNS-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }
        If ($DSC) # Desired State Configuration
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-DSC-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-DSC-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }
        If ($Clustering) # Failover Clustering
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-FailoverCluster-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-FailoverCluster-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }
        If ($GuestDrivers) # Hyper-V Guest Driver Integration
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-Guest-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-Guest-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }
        If ($IIS) # IIS Server
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-IIS-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-IIS-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }
        If ($NPDS) # Network Performance Diagnostics Service
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-NPDS-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-NPDS-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }
        If ($OEMDrivers) # OEM Drivers
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-OEM-Drivers-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-OEM-Drivers-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }
        If ($Storage) # File Server and Storage Components
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-NanoServer-Storage-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-NanoServer-Storage-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }
        If ($ReverseForwarders) # Reverse Forwarders for App compat
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-OneCore-ReverseForwarders-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-OneCore-ReverseForwarders-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }
        If ($SCVMM) # System Center VMM components
        {
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-Windows-Server-SCVMM-Compute-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-Windows-Server-SCVMM-Compute-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\Microsoft-Windows-Server-SCVMM-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        Add-WindowsPackage -PackagePath "$($MediaPath)NanoServer\Packages\en-us\Microsoft-Windows-Server-SCVMM-Package.cab" -Path "$Destination\Mount\" | Out-NULL
        }

        New-Item -Path "$Destination\Mount\Windows\Setup\Scripts" -Force -ItemType Directory | Out-Null
        New-Item -Path "$Destination\Mount\Windows\Setup\Scripts\SetupComplete.cmd" -Value $SetupComplete -Force -ItemType File | Out-Null

        Dismount-WindowsImage -Path "$Destination\Mount" -Save | Out-Null
        
        Remove-Item -Path "$Destination\NanoCustom.wim" -ErrorAction SilentlyContinue | Out-Null
        Copy-Item -path "$Destination\NanoServer.wim" -destination "$Destination\NanoCustom.wim" | Out-Null
        Return "$Destination\NanoCustom.wim"


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
Import-Module ($DriveLetter+':\DeployImage\DeployImage.Psd1)'
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
        Remove-Item -Path "$Destination\Custom.wim" | Out-Null
        Rename-Item -Path "$Destination\Boot.wim" -NewName 'Custom.wim' | Out-Null
        Remove-item -Path $WinPETemp -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        Return "$Destination\Custom.wim"

        }
    End
    {
    }
}
