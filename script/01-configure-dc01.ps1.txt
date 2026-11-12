<#
.SYNOPSIS
    Prepares a fresh Windows Server 2022 VM to become a domain controller.
 
.DESCRIPTION
    Sets a static IP address, points DNS at the server itself, and renames
    the computer to DC01. The server restarts at the end.
 
    Run in an elevated PowerShell window (Run as administrator).
 
.NOTES
    Lab network: VirtualBox NAT Network "LabNet" (10.0.2.0/24)
#>
 
$InterfaceAlias = "Ethernet"      # Check with Get-NetAdapter if yours differs
$IPAddress      = "10.0.2.10"
$PrefixLength   = 24
$Gateway        = "10.0.2.1"
$ComputerName   = "DC01"
 
# Static IP address and default gateway
New-NetIPAddress -InterfaceAlias $InterfaceAlias `
                 -IPAddress $IPAddress `
                 -PrefixLength $PrefixLength `
                 -DefaultGateway $Gateway
 
# The domain controller will host DNS, so it uses itself as its DNS server
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses 127.0.0.1
 
# Rename and restart
Rename-Computer -NewName $ComputerName -Restart
 