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
Clear-Disk -Number $Disk.Number -RemoveData -RemoveOEM
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
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$SystemDrive='S',
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [string]$OSDrive='W'
                
     )

    Clear-DiskStructure $Disk

    Initialize-Disk -Number $Disk.Number -PartitionStyle GPT

    $Partition=New-Partition -DiskNumber $Disk.Number -Size 128MB ; # Create Microsoft Basic Partition
    $Partition | Format-Volume -FileSystem Fat32 -NewFileSystemLabel 'MSR'
    $Partition | Set-Partition -DiskNumber $Disk.Number -PartitionNumber $Partition.PartitionNumber -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'

    $Partition=New-Partition -DiskNumber $Disk.Number -Size 300MB -isactive; # Create Microsoft Basic Partition and Set System as bootable
    $Partition | Format-Volume -FileSystem Fat32 -NewFileSystemLabel 'System' -DriveLetter $SystemDrive
    $Partition | Set-Partition -DiskNumber $Disk.Number -PartitionNumber $Partition.PartitionNumber -GptType '"{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'

    $Partition=New-Partition -DiskNumber $Disk.Number -UseMaximumSize ; # Take remaining Disk space for Operating System
    $Partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel 'Windows' -DriveLetter $OSDrive
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
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$SystemDrive='S',
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [string]$OSDrive='W'
                
     )

Clear-DiskStructure $Disk

    Initialize-Disk -Number $Disk.Number -PartitionStyle MBR

    $Partition=New-Partition -DiskNumber $Disk.Number -UseMaximumSize -isactive; # Single Partition for System and Operating System
    $Partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel 'Windows' -DriveLetter $OSDrive
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
        Copy-Item -Path "$filename" -Destination "$OSDrive`:\Windows\System32\Sysprep\unattend.xml"
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

function New-VirtualDisk
{
[CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [System.String]$Vhd,
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [System.Int64]$Size
    )
            New-VHD -Path $Vhd -SizeBytes $Size -Dynamic
        Mount-VHD -Path $vhd
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
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$SystemDrive='Y',
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$OSDrive='Z',
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$NanoDrive,
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        $Disk,
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        $SetupComplete,
        [Parameter(Mandatory=$true,
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
        $Disk=New-VirtualDisk -Vhd $Vhd -Size $Size
        
        Clear-DiskStructure -Disk $Disk
        New-VirtualPartitionStructure -Disk $Disk -SystemDrive $SystemDrive -OSDrive $OSDrive
        }
        Else
        {
        Clear-DiskStructure -Disk $Disk
        New-PhysicalPartitionStructure -Disk $disk -SystemDrive -OSDrive $OSDrive
        }
        Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\"
        
        Send-BootCode -SystemDrive $SystemDrive -OSDrive $OSDrive
        
        $UnattendXML=New-Unattend -Computername $computername -Timezone $Timezone -Owner $Owner -Organization $Organization -AdminPassword $AdminPassword -Domain $DomainName -DomainAccount $DomainAccount -DomainPassword $DomainPassword -DomainOU $DomainOU
        
        Send-Unattend -OSDrive $OSDrive -UnattendData $UnattendXML

        Add-WindowsPackage -PackagePath "$(NanoDrive)\NanoServer\Packages\Microsoft-NanoServer-Guest-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$(NanoDrive)\NanoServer\Packages\Microsoft-NanoServer-Compute-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$(NanoDrive)\NanoServer\Packages\Microsoft-NanoServer-Defender-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$(NanoDrive)\NanoServer\Packages\Microsoft-NanoServer-OEM-Drivers-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$(NanoDrive)\NanoServer\Packages\en-us\Microsoft-NanoServer-Guest-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$(NanoDrive)\NanoServer\Packages\en-us\Microsoft-NanoServer-Compute-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$(NanoDrive)\NanoServer\Packages\en-us\Microsoft-NanoServer-Defender-Package.cab" -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath "$(NanoDrive)\NanoServer\Packages\en-us\Microsoft-NanoServer-OEM-Drivers-Package.cab" -Path "$OSDrive`:\"
        
        If ($DriverPath -ne $NULL)
        {
        Add-WindowsDriver -Driver $DriverPath -Recurse -Path "$OSDrive`:\" -ErrorAction SilentlyContinue
        }

        New-Item -Path "$OSDrive`:\Windows\Setup\Scripts" -Force -ItemType File
        New-Item -Path "$OSDrive`:\Windows\Setup\Scripts\SetupComplete.cmd" -Value $SetupComplete -Force -ItemType File
        
        If($Virtual)
            {
            Dismount-VHD -Path $nanovhd
        
            New-VM -Name $Computername -MemoryStartupBytes 512mb -SwitchName $Switchname -VHDPath $Nanovhd
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

        Clear-DiskStructure -Disk $Disk
        New-PhysicalPartitionStructure -Disk $disk -SystemDrive -OSDrive $OSDrive
        Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\"
        
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
Export-ModuleMember -Function *
