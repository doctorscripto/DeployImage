# DeployImage
The goal of this PowerShell Module initially is to supply a better and easier way to image the new Nano Server from Microsoft.   However since the processes are for the most part identical, I am going to extend this to Windows to Go deployments as well as standard servers (whether physical or virtual)

It will have to ability to create a Workgroup or Domain based Unattend.xml file to be injected directly into the destination environment.

In addition (as it grows and improves) it will be able to inject features directly into the relevant operating systems.

Another target of this Module is to allow easy Deployment of a Windows PE key that is PowerShell enabled.

This module can be found on the PowerShell Gallery under 'DeployImage' and also on Github under https://github.com/energizedtech/DeployImage

It introduces 13 new Cmdlets to try and simplify Deploying Nanoserver and Wim files to VHD, USB and Physical Disk environments.  (Nano Server being the Dominant reason)

Clear-DiskStructure

This Cmdlets task is to Enhance the Clear-Disk Cmdlet and simplify it as I have encountered situations in which you need to remove Partitions first before Clear-Disk successfully cleans the Target Disk

Copy-WithProgress              

This Cmdlet is still being tested and is meant as a "Copy-Item" with Progress to show SOME indication of where a large folder copy is at

Get-ArchitectureString         

This Cmdlet returns the string " (x86)" if you are on 64bi Windows.  It is meant as a way to inject into the 32 Program Files pathname

Get-ActiveDriveLetter

This Cmdlet pulls up an array of Drive Letters presently in use

Test-ActiveDriveLetter

It will provide a Boolean $True or $False if a Drive Letter is in use when provided

Get-NextActiveDriveLetter

This Cmdlet will identify the next available drive letter for mapping or other purposes

Get-AttachedDisk                

Get-AttachedDisk is a Wrapper on the Get-Disk Cmdlet which targets either Internal or USB.  It also provides a GUI parameter to launch Out-Gridview to select disks

New-PartitionStructure         

This Cmdlet creates one of three stock basic Parition structures, either MBR for USB, MBR for Filesystem or GPT for UEFI and Formats targeted drives

New-UnattendXMLContent    

This is a Parameterized Cmdlet to provide an Unattend.XML file content.  Domain Join is an option and will populate the additional needed content.

New-WindowsPEWim            

This builds a WindowsPE Wim file pre-populated with the necessary OCS for Windows PowerShell, DISM and Storage Cmdlets.  It also autolaunches PowerShell with the Set-ExecutionPolicy to Bypass

Remove-DriveLetter             

This simply Removes and verifies removal of a Drive Letter from the Drive system

Send-BootCode

Makes a Disk bootable

Send-SanPolicy                     

This is meant for Windows to Go.  It just builds and applies a targeted disk with the SanPolicy for Windows to Go

Send-UnattendXML                 

Deploys an Unattend file to a target Operating System

Test-WindowsADK

Test for the Presence of the Windows 10 ADK

There are also a sample script provided

DeployWindowsPE.ps1

Prompts for an available USB key, Prepares it as Bootable WinPE with PowerShell

