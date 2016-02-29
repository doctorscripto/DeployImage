param(
$SystemDrive='L',
# Drive Letter being assigned to Windows Drive
#
$OSDrive='L',
# Netbios name of computer and VMName
#
$Computername='Contoso-Win7'
)
$VHD=Convert-WimtoVhd -Wimfile C:\Windows7\install.wim -vm $Computername

$Mount=Mount-vhd $VHD
Add-PartitionAccessPath -DiskId 

# Clear out the old Unattend.xml file if it exists
#
Remove-Item -Path Unattend.xml -Force -ErrorAction SilentlyContinue

# Create an Unattend.XML to define the Computername, owner, 
# Timezone and default Admin Password
#
$XMLContent=New-UnattendXMLContent -Computername $Computername -Timezone 'Eastern Standard Time' -Owner 'Contoso' -Organization 'Contoso' -AdminPassword 'P@ssw0rd' -Online -DomainName Contoso -DomainAccount 'Administrator' -DomainPassword 'P@ssw0rd'

# Create the Unattend.xml file
#
New-Item -ItemType File -Name Unattend.xml -Force | Out-Null
Add-content Unattend.xml -Value $XMLContent

# Inject the Unattend.xml file into the VHD image
#
Copy .\Unattend.xml "$OSdrive`:\Windows\system32\sysprep"

# Build the post Unattend.xml - Pre login script
# This will define the static IP address and Perform an 
# Offline Domain Join from the provide domainjoin.djoin file
#
$SetupCompleteCMD=@"
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
