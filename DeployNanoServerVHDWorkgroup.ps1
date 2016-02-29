param(
# Size of the VHD file
#
$Size=20GB,
# Location of the Nanoserver Wim created by 
# New-NanoServerWim
#
$Wimfile='C:\NanoTemp\NanoCustom.wim',
# In the case of a single partition setup like 
# USB Key or simple VHD SystemDrive and OSDrive
# Will be the same Letter
#
# Drive Letter being assigned to Boot Drive
#
$SystemDrive='L',
# Drive Letter being assigned to Windows Drive
#
$OSDrive='L',
# Netbios name of computer and VMName
#
$Computername='Contoso-Nano1',
# Static IPv4 address
#
$IPAddress='192.168.1.15',
# IPv4 Subnet Mask
#
$Subnet='255.255.255.0',
# IPv4 Gateway
#
$Gateway='192.168.1.1',
# IPv4 IP address of DNS Server
#
$DNS='192.168.1.5'
)
# Obtain the default location of 
# Virtual HardDisks in Hyper-V
#
$VHDPath=(Get-VMhost).VirtualHardDiskPath

# Define VHD filename 
#
$VHD="$VhdPath\$Computername.vhd"

# Create a new VHD
#
New-VHD -Path $Vhd -SizeBytes $Size -Dynamic | Out-Null

# Mount the VHD and identify it's Disk Object
#
Mount-VHD -Path $vhd | Out-Null
$Disk=Get-Vhd -Path $Vhd | Get-Disk

# Create a new Partition Structure of style
# MBR, Format and Partition System and OSDrive
#
New-PartitionStructure -Disk $disk -MBR -BootDrive $SystemDrive -OSDrive $OsDrive

# Expand the Windows Image for Nano Server to the OSDrive
#
Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\"

# Send the Boot files to the Disk Structure
#
Send-BootCode -BootDrive $SystemDrive -OSDrive $OSDrive

# Clear out the old Unattend.xml file if it exists
#
Remove-Item -Path Unattend.xml -Force -ErrorAction SilentlyContinue

# Create an Unattend.XML to define the Computername, owner, 
# Timezone and default Admin Password
#
$XMLContent=New-UnattendXMLContent -Computername Contoso-Nano1 -Timezone 'Eastern Standard Time' -Owner 'Contoso' -Organization 'Contoso' -AdminPassword 'P@ssw0rd'

# Create the Unattend.xml file
#
New-Item -ItemType File -Name Unattend.xml -Force | Out-Null
Add-content Unattend.xml -Value $XMLContent

# Inject the Unattend.xml file into the VHD image
#
Copy .\Unattend.xml "$OSdrive`:\Windows\system32\sysprep"

# Build the post Unattend.xml - Pre login script
# This will define the static IP addres
#
$SetupCompleteCMD=@"
netsh interface ipv4 set address Name="Ethernet" static $IPAddress $Subnet $Gateway
netsh dns set dnsservers name="Ethernet" source=static address=$DNS
shutdown -f -r -t 0
"@

# Remove the old SetupComplete.CMD if it exists
#
Remove-Item -Path SetupComplete.cmd -Force -ErrorAction SilentlyContinue

# Create the new one
#
New-Item -ItemType File -Name SetupComplete.cmd -Force | Out-Null
Add-content SetupComplete.cmd -Value $SetupCompleteCMD

# Inject into the disk image
#
Copy .\SetupComplete.cmd "$OSdrive`:\Windows\setup\scripts"

# Remove Drive Letter from Assigned Disk and place 
# back into pool. 
#
Remove-DriveLetter -DriveLetter $OSDrive

# Disconnect VHD
#
Dismount-VHD -Path $vhd

# From this point forward you can manually create a
# Virtual Machine in Hyper-V or use this VHD file for
# booting on a Physical Disk
