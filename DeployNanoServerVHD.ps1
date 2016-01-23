$Vhd='C:\VM\NanoVHD.Vhd'
$Size=20GB
$Wimfile='C:\NanoTemp\NanoCustom.wim'
$SystemDrive='L'
$OSDrive='L'
$Computername='Contoso-Nano1'
$IPAddress='192.168.1.15'
$Subnet='255.255.255.0'
$Gateway='192.168.1.1'
$DNS='192.168.1.5'
$Domain='Contoso.local'
$ODJFile='domainjoin.djoin'

New-VHD -Path $Vhd -SizeBytes $Size -Dynamic | Out-Null
Mount-VHD -Path $vhd | Out-Null
$Disk=Get-Vhd -Path $Vhd | Get-Disk

New-PartitionStructure -Disk $disk -MBR -BootDrive $SystemDrive -OSDrive $OsDrive
Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\"
Send-BootCode -BootDrive $SystemDrive -OSDrive $OSDrive

Remove-Item $ODJFile -ErrorAction SilentlyContinue
Djoin.exe /Provision /Domain $Domain /machine $Computername /savefile $ODJFile

# Code to grab the Offline Blob content for Unattend.xml
# $OfflineBlob=(Get-Content DomainJoin.djoin).replace([char][byte]0,' ').trim()
# Although Unattend.xml is supported for the Offline Domain Join, it does not seem to work in Nano TP4
#
Copy-Item .\DomainJoin.djoin "$OSdrive`:\programdata"
Remove-Item -Path Unattend.xml -Force -ErrorAction SilentlyContinue
$XMLContent=New-UnattendXMLContent -Computername Contoso-Nano1 -Timezone 'Eastern Standard Time' -Owner 'Contoso' -Organization 'Contoso' -AdminPassword 'P@ssw0rd'
New-Item -ItemType File -Name Unattend.xml -Force | Out-Null
Add-content Unattend.xml -Value $XMLContent
Copy .\Unattend.xml "$OSdrive`:\Windows\system32\sysprep"

$SetupCompleteCMD=@"
netsh interface ipv4 set address Name="Ethernet" static $IPAddress $Subnet $Gateway
netsh dns set dnsservers name="Ethernet" source=static address=$DNS
djoin /requestodj /loadfile C:\Programdata\domainjoin.djoin /windowspath c:\windows /localos
shutdown -f -r -t 0
"@

Remove-Item -Path SetupComplete.cmd -Force -ErrorAction SilentlyContinue
New-Item -ItemType File -Name SetupComplete.cmd -Force | Out-Null
Add-content SetupComplete.cmd -Value $SetupCompleteCMD
Copy .\SetupComplete.cmd "$OSdrive`:\Windows\setup\scripts"

Remove-DriveLetter -DriveLetter $OSDrive

Dismount-VHD -Path $vhd
