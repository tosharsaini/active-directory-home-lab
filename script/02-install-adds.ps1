<#
.SYNOPSIS
    Installs Active Directory Domain Services and creates the lab.local forest.
 
.DESCRIPTION
    Adds the AD DS role with management tools, then promotes the server to
    the first domain controller of a new forest, with DNS installed.
 
    You are prompted for a Directory Services Restore Mode (DSRM) password.
    The server restarts automatically when promotion finishes.
 
    Run in an elevated PowerShell window after 01-configure-dc01.ps1.
#>
 
$DomainName = "lab.local"
 
# Install the AD DS role and the admin tools (ADUC, GPMC, PowerShell module)
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
 
# Create the new forest and domain, and install DNS on this server
Install-ADDSForest -DomainName $DomainName -InstallDns
 
# After the restart, verify with:
#   Get-ADDomain
#   Get-Service NTDS, DNS, Netlogon
 