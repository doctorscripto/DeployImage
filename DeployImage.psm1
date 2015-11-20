function Test-WindowsADK
{
Test-Path 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment' -or 'C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment'
}

function Get-Architecture
{
$Arch=(Get-CimInstance win32_operatingsystem).OSArchitecture
if ($Arch='32-Bit')
    {
    Return [string]' (x86)'
    }

}

function Get-USBDisk
{
Get-Disk | Where { $_.BusType -eq 'USB' } | Out-GridView -PassThru
}

function Get-InternalDisk
{
Get-Disk | Where { $_.BusType -eq 'SATA' -or $_.BusType -eq 'SCSI' } | Out-GridView -PassThru
}

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

function New-PhysicalPartitionStructure
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
        [string]$SystemDrive,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [string]$OSDrive
                
     )

    Clear-DiskStructure $Disk

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

function New-USBPartitionStructure
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
        [string]$OSDrive
                
     )

    Clear-DiskStructure $Disk

    Initialize-Disk -Number $Disk.Number -ErrorAction SilentlyContinue

    $Partition=New-Partition -DiskNumber $Disk.Number -DriveLetter $OSDrive -UseMaximumSize -IsActive ; # Take remaining Disk space for Operating System
    Format-Volume -Partition $Partition  -FileSystem FAT32 -NewFileSystemLabel 'Windows'
    
}

function New-VirtualPartitionStructure
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
        [string]$OSDrive
                
     )

    Clear-DiskStructure $Disk

    Initialize-Disk -Number $Disk.Number -PartitionStyle MBR
    $Partition=New-Partition -DiskNumber $Disk.Number -UseMaximumSize -isactive -DriveLetter $OSDrive; # Single Partition for System and Operating System
    Format-Volume -Partition $Partition -FileSystem NTFS -NewFileSystemLabel 'Windows' 
}

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
        [string]$OSDrive
    )
    & "$($env:windir)\system32\bcdboot" "$SystemDrive`:\Windows" /s "$OSDrive`:"  /f ALL
}

function Send-USBBootCode
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$OSDrive
    )
    & "$($env:windir)\system32\bootsect.exe" /nt60 "$OSDrive`:"
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
function New-NanoServer
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
        [string]$DomainOU,
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=10)]
        [string]$Wimfile,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='VirtualDisk')]
        [switch]$Virtual,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='VirtualDisk')]
        [switch]$Domain,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='VirtualDisk')]
        [string]$Vhd,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='VirtualDisk')]
        [int64]$Size=20GB,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='VirtualDisk')]
        [string]$Switchname='Internal',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='VirtualDisk')]
        [int64]$MemoryStartup=512MB,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$SystemDrive='Y',
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$OSDrive='Z',
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$NanoDrive,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $Disk,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $SetupComplete,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        $DriverPath
     )

    Begin
    {
    }
 
    Process
    {

        If ($Virtual)
        {
        $Disk=New-VirtualDiskForImage -Vhd $Vhd -Size $Size
        
        New-VirtualPartitionStructure -Disk $Disk -OSDrive $OSDrive
        }
        Else
        {
        New-PhysicalPartitionStructure -Disk $disk -SystemDrive $SystemDrive -OSDrive $OSDrive
        }
        
        Expand-WindowsImage –imagepath "$($NanoDrive)\NanoServer\$wimfile" –index 1 –ApplyPath "$OSDrive`:\" -LogPath "$($Env:temp)\Dism$((Get-Date -Format 'MMddyyyyhhmmssmm').tostring()).log"
        
        If ($Virtual)
        {
        Send-BootCode -SystemDrive $OSDrive -OSDrive $OSDrive
        }
        Else
        {
        Send-BootCode -SystemDrive $SystemDrive -OSDrive $OSDrive
        }

        If ($JoinDomain)
        {
        $UnattendXML=New-Unattend -Computername $computername -Timezone $Timezone -Owner $Owner -Organization $Organization -AdminPassword $AdminPassword -JoinDomain -Domainname $DomainName -DomainAccount $DomainAccount -DomainPassword $DomainPassword -DomainOU $DomainOU
        }
        Else
        {
        $UnattendXML=New-Unattend -Computername $computername -Timezone $Timezone -Owner $Owner -Organization $Organization -AdminPassword $AdminPassword
        }

        Send-Unattend -OSDrive $OSDrive -UnattendData $UnattendXML

        Add-WindowsPackage -PackagePath "$($NanoDrive)\NanoServer\Packages\Microsoft-NanoServer-Guest-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$($NanoDrive)\NanoServer\Packages\Microsoft-NanoServer-Compute-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$($NanoDrive)\NanoServer\Packages\Microsoft-NanoServer-Defender-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$($NanoDrive)\NanoServer\Packages\Microsoft-NanoServer-OEM-Drivers-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$($NanoDrive)\NanoServer\Packages\en-us\Microsoft-NanoServer-Guest-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$($NanoDrive)\NanoServer\Packages\en-us\Microsoft-NanoServer-Compute-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$($NanoDrive)\NanoServer\Packages\en-us\Microsoft-NanoServer-Defender-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$($NanoDrive)\NanoServer\Packages\en-us\Microsoft-NanoServer-OEM-Drivers-Package.cab" -Path "$OSDrive`:\"
        
        If ($DriverPath -ne $NULL)
        {
        Add-WindowsDriver -Driver $DriverPath -Recurse -Path "$OSDrive`:\" -ErrorAction SilentlyContinue
        }

        New-Item -Path "$OSDrive`:\Windows\Setup\Scripts" -Force -ItemType Directory
        New-Item -Path "$OSDrive`:\Windows\Setup\Scripts\SetupComplete.cmd" -Value $SetupComplete -Force -ItemType File
        
        If($Virtual)
            {
            Dismount-VHD -Path $vhd
        
            New-VM -Name $Computername -MemoryStartupBytes 512mb -SwitchName $Switchname -VHDPath $vhd
            }
        }
End
        {
        }
}
function New-WindowToGo
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
        
        Copy-Item -path "$WinAdk\en-us\$Wimfile" -Destination "$WinPETemp\Media\Sources\boot.wim"
        
        New-USBPartitionStructure -Disk $disk -OSDrive $OSDrive

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

        $WinPEKey="$OsDrive`:\"
	Copy-Item -Path "$WinPETemp\Media\*" -destination $WinPeKey -Recurse
        
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
Export-ModuleMember -Function *
