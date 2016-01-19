$Vhd='C:\VM\NanoVHD.Vhd'
$Size=20GB
$Wimfile='C:\NanoTemp\NanoCustom.wim'
$SystemDrive='L'
$OSDrive='L'

New-VHD -Path $Vhd -SizeBytes $Size -Dynamic | Out-Null
Mount-VHD -Path $vhd | Out-Null
$Disk=Get-Vhd -Path $Vhd | Get-Disk

Clear-DiskStructure -Disk $disk
New-PartitionStructure -Disk $disk -MBR -BootDrive $SystemDrive -OSDrive $OsDrive
Expand-WindowsImage –imagepath "$wimfile" –index 1 –ApplyPath "$OSDrive`:\"
Send-BootCode -BootDrive $SystemDrive -OSDrive $OSDrive
Remove-Item -Path Unattend.xml -Force -ErrorAction SilentlyContinue
$XMLContent=New-UnattendXMLContent -Computername Contoso-Nano1 -Timezone 'Eastern Standard Time' -Owner 'Contoso' -Organization 'Contoso' -AdminPassword 'P@ssw0rd'
New-Item -ItemType File -Name Unattend.xml -Force | Out-Null
Add-content Unattend.xml -Value $XMLContent
Copy .\Unattend.xml "$OSdrive`:\Windows\system32\sysprep"

Remove-Item DomainJoin.djoin -ErrorAction SilentlyContinue
Djoin.exe /Provision /Domain 'Contoso' /machine 'Contoso-Nano1' /savefile DomainJoin.djoin
Copy-Item DomainJoin.join "$OSdrive`:\Windows\system32\sysprep"

$SetupCompleteCMD=@"
Djoin.exe /RequestODJ /loadfile c:\Windows\system32\sysprep\DomainJoin.djoin /windowspath C:\windows /localos 
"@

Remove-Item -Path SetupComplete.cmd -Force -ErrorAction SilentlyContinue
New-Item -ItemType File -Name SetupComplete.cmd -Force | Out-Null
Add-content SetupComplete.cmd -Value $SetupCompleteCMD
Copy .\SetupComplete.cmd "$OSdrive`:\Windows\system32\sysprep"

Remove-DriveLetter -DriveLetter $OSDrive

Dismount-VHD -Path $vhd
