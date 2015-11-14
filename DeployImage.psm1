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
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=5)]
        [switch]$Domain,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=6)]
        [string]$DomainName,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=7)]
        [string]$DomainAccount,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=8)]
        [string]$DomainPassword,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=9)]
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

If($Domain)
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
                   Position=6)]
        [string]$DomainName,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=7)]
        [string]$DomainAccount,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=8)]
        [string]$DomainPassword,
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=9)]
        [string]$DomainOU,
        [switch]$Virtual,
        [switch]$Domain
        
     )

    Begin
    {
    }
 
    Process
    {

        $SystemDrive='Y'
        $OSDrive='Z'
        $Wimfile='C:\NanoServer\NanoServer.Wim'
        $NanoVHD="C:\Nanoserver\$Computername.vhd"

        If ($Virtual)
        {
        New-VHD -Path $Nanovhd -SizeBytes 20GB -Dynamic
        Mount-VHD -Path $Nanovhd
       $Disk=Get-Vhd -Path $Nanovhd | Get-Disk
        Get-Disk -Number ($Disk.number) | Get-Partition | Remove-partition -confirm:$false -ea SilentlyContinue
        Clear-Disk –Number ($Disk.number) -RemoveData -RemoveOEM -confirm:$False -ea SilentlyContinue
        Initialize-Disk –Number ($Disk.Number) -PartitionStyle MBR
        $OSPartition = New-Partition –InputObject $Disk -UseMaximumSize -IsActive
        Format-Volume -NewFileSystemLabel "Windows" -FileSystem NTFS -Partition $OSPartition -confirm:$False
        Set-Partition -InputObject $OSPartition -NewDriveLetter $OSDrive
        }
        Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\"
        
        Send-BootCode -SystemDrive $SystemDrive -OSDrive $OSDrive
        
        $UnattendXML=New-Unattend -Computername $computername -Timezone $Timezone -Owner $Owner -Organization $Organization -AdminPassword $AdminPassword -Domain $DomainName -DomainAccount $DomainAccount -DomainPassword $DomainPassword -DomainOU $DomainOU
        
        Send-Unattend -OSDrive $OSDrive -UnattendData $UnattendXML

        Add-WindowsPackage -PackagePath C:\NanoServer\Packages\Microsoft-NanoServer-Guest-Package.cab -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath C:\NanoServer\Packages\Microsoft-NanoServer-Compute-Package.cab -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath C:\NanoServer\Packages\Microsoft-NanoServer-Defender-Package.cab -Path "$OSDrive`:\"
        Add-WindowsPackage -PackagePath C:\NanoServer\Packages\Microsoft-NanoServer-OEM-Drivers-Package.cab -Path "$OSDrive`:\"
        Add-WindowsDriver -Driver c:\NanoServer\Drivers -Recurse -Path "$OSDrive`:\" -ErrorAction SilentlyContinue

        New-Item -Path "$OSDrive`:\Windows\Setup\Scripts" -Force -ItemType File
        Copy-item -Path C:\NanoServer\SetupComplete.cmd -Destination "$OSDrive`:\Windows\Setup\Scripts" -Force -ErrorAction SilentlyContinue
        Dismount-VHD -Path $nanovhd

        $Switchname='Internal'
        $MemoryStartup=512mb

        New-VM -Name $Computername -MemoryStartupBytes 512mb -SwitchName $Switchname -VHDPath $Nanovhd
        }
    End
        {
        }
}
Export-ModuleMember -Function *
