<#
.SYNOPSIS
    Creates the department file share and a Group Policy for the lab.local domain.

.DESCRIPTION
    Part 1 - File share
      - Creates C:\Shares\Departments with IT, HR, Sales and Finance folders
      - Each folder can only be opened by its own group (GRP-IT, GRP-HR, ...)
      - Shares the parent folder as \\DC01\Departments

    Part 2 - Group Policy "LabUsers - Desktop Policy", linked to the LabUsers OU
      - Locks the screen after 10 minutes of inactivity (password required)
      - Blocks Control Panel and Settings for standard users
      - Saves an HTML report of the policy to C:\Shares\GPO-Report.html

    Run on DC01 in an elevated PowerShell window.
#>

Import-Module ActiveDirectory
Import-Module GroupPolicy

# ---------------- Part 1: Department file share ----------------
$Root  = "C:\Shares\Departments"
$Depts = "IT", "HR", "Sales", "Finance"

New-Item -Path $Root -ItemType Directory -Force | Out-Null

foreach ($d in $Depts) {
    $path = Join-Path $Root $d
    New-Item -Path $path -ItemType Directory -Force | Out-Null
    icacls $path /inheritance:r /grant "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "LAB\GRP-${d}:(OI)(CI)M" | Out-Null
    Write-Host "Folder $d : only GRP-$d can open it" -ForegroundColor Green
}

if (-not (Get-SmbShare -Name "Departments" -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name "Departments" -Path $Root -FullAccess "Authenticated Users" | Out-Null
}
Write-Host "Share created: \\DC01\Departments" -ForegroundColor Green

# ---------------- Part 2: Group Policy ----------------
$GpoName = "LabUsers - Desktop Policy"
$OU      = "OU=LabUsers," + (Get-ADDomain).DistinguishedName

if (-not (Get-GPO -Name $GpoName -ErrorAction SilentlyContinue)) {
    New-GPO -Name $GpoName -Comment "Screen lock after 10 minutes; Control Panel blocked" | Out-Null
}

$Desk = "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop"
Set-GPRegistryValue -Name $GpoName -Key $Desk -ValueName "ScreenSaveActive"    -Type String -Value "1"   | Out-Null
Set-GPRegistryValue -Name $GpoName -Key $Desk -ValueName "ScreenSaverIsSecure" -Type String -Value "1"   | Out-Null
Set-GPRegistryValue -Name $GpoName -Key $Desk -ValueName "ScreenSaveTimeOut"   -Type String -Value "600" | Out-Null
Set-GPRegistryValue -Name $GpoName -Key $Desk -ValueName "SCRNSAVE.EXE"        -Type String -Value "scrnsave.scr" | Out-Null

Set-GPRegistryValue -Name $GpoName `
    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
    -ValueName "NoControlPanel" -Type DWord -Value 1 | Out-Null

if (-not ((Get-GPInheritance -Target $OU).GpoLinks | Where-Object DisplayName -eq $GpoName)) {
    New-GPLink -Name $GpoName -Target $OU | Out-Null
}
Write-Host "GPO '$GpoName' linked to $OU" -ForegroundColor Green

Get-GPOReport -Name $GpoName -ReportType Html -Path "C:\Shares\GPO-Report.html"
Write-Host "GPO report saved to C:\Shares\GPO-Report.html" -ForegroundColor Green

# ---------------- Summary for screenshots ----------------
Get-SmbShare -Name "Departments" | Format-Table Name, Path -AutoSize
foreach ($d in $Depts) {
    Write-Host "--- $d ---"
    (Get-Acl (Join-Path $Root $d)).Access | Format-Table IdentityReference, FileSystemRights -AutoSize -HideTableHeaders
}
Get-GPInheritance -Target $OU | Select-Object -ExpandProperty GpoLinks | Format-Table DisplayName, Enabled, Target -AutoSize
