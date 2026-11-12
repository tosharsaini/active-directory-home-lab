<#
.SYNOPSIS
    Creates department OUs, security groups, and user accounts from a CSV file.
 
.DESCRIPTION
    For every row in users.csv this script:
      - creates the department OU under "LabUsers" if it does not exist
      - creates a department security group if it does not exist
      - creates the user account in the department OU
      - adds the user to the department group
      - forces a password change at first logon
 
    Usernames are built as first initial + last name (for example, asingh).
    The starting password is typed at a prompt and is never stored in the file.
 
    Run on the domain controller in an elevated PowerShell window:
        .\03-create-ous-groups-users.ps1 -CsvPath .\users.csv
 
.PARAMETER CsvPath
    Path to a CSV file with the columns FirstName, LastName, Department, JobTitle.
#>
 
param(
    [string]$CsvPath = ".\users.csv"
)
 
Import-Module ActiveDirectory
 
$Domain   = Get-ADDomain
$DomainDN = $Domain.DistinguishedName
$DnsRoot  = $Domain.DNSRoot
$RootOU   = "LabUsers"
$RootDN   = "OU=$RootOU,$DomainDN"
 
if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"
    exit 1
}
 
$Password = Read-Host -AsSecureString "Enter the starting password for new users"
 
# Top-level OU that holds all department OUs
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$RootOU'" -SearchBase $DomainDN -SearchScope OneLevel)) {
    New-ADOrganizationalUnit -Name $RootOU -Path $DomainDN
    Write-Host "Created OU: $RootOU" -ForegroundColor Green
}
 
$Created = 0
$Skipped = 0
 
foreach ($Row in Import-Csv $CsvPath) {
 
    $Dept      = $Row.Department.Trim()
    $DeptDN    = "OU=$Dept,$RootDN"
    $GroupName = "GRP-$Dept"
    $Username  = ($Row.FirstName.Substring(0,1) + $Row.LastName).ToLower() -replace '[^a-z0-9]', ''
    $FullName  = "$($Row.FirstName) $($Row.LastName)"
 
    # Department OU
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$Dept'" -SearchBase $RootDN -SearchScope OneLevel)) {
        New-ADOrganizationalUnit -Name $Dept -Path $RootDN
        Write-Host "Created OU: $Dept" -ForegroundColor Green
    }
 
    # Department security group
    if (-not (Get-ADGroup -Filter "Name -eq '$GroupName'")) {
        New-ADGroup -Name $GroupName -GroupScope Global -GroupCategory Security -Path $DeptDN
        Write-Host "Created group: $GroupName" -ForegroundColor Green
    }
 
    # User account
    if (Get-ADUser -Filter "SamAccountName -eq '$Username'") {
        Write-Host "Skipped (already exists): $Username" -ForegroundColor Yellow
        $Skipped++
        continue
    }
 
    New-ADUser -Name $FullName `
               -GivenName $Row.FirstName `
               -Surname $Row.LastName `
               -SamAccountName $Username `
               -UserPrincipalName "$Username@$DnsRoot" `
               -Department $Dept `
               -Title $Row.JobTitle `
               -Path $DeptDN `
               -AccountPassword $Password `
               -ChangePasswordAtLogon $true `
               -Enabled $true
 
    Add-ADGroupMember -Identity $GroupName -Members $Username
 
    Write-Host "Created user: $Username ($FullName, $Dept)" -ForegroundColor Green
    $Created++
}
 
Write-Host ""
Write-Host "Done. Users created: $Created. Skipped: $Skipped."
 
