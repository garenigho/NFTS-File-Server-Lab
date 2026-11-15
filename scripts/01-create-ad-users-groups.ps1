Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Import-Module ActiveDirectory

# Wait for AD to respond after the reboot
$ready = $false
for ($i = 1; $i -le 20 -and -not $ready; $i++) {
    try { Get-ADDomain | Out-Null; $ready = $true }
    catch { Write-Host "Waiting for AD... attempt $i"; Start-Sleep -Seconds 15 }
}
if (-not $ready) { throw "Active Directory did not become ready." }

$domain   = "lab.local"
$domainDN = "DC=lab,DC=local"
$password = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force

foreach ($ou in @("Lab Users", "Lab Computers", "Lab Groups")) {
    New-ADOrganizationalUnit -Name $ou -Path $domainDN -ProtectedFromAccidentalDeletion $false
    Write-Host "Created OU: $ou" -ForegroundColor Yellow
}

foreach ($group in @("GRP_Finance", "GRP_HR", "GRP_Sales", "GRP_IT")) {
    New-ADGroup -Name $group -GroupScope Global -GroupCategory Security -Path "OU=Lab Groups,$domainDN"
    Write-Host "Created group: $group" -ForegroundColor Yellow
}

$users = @(
    @{ First = "John";  Last = "Smith"; Username = "john.smith";  Group = "GRP_IT" },
    @{ First = "Sarah"; Last = "Jones"; Username = "sarah.jones"; Group = "GRP_Finance" },
    @{ First = "Mike";  Last = "Brown"; Username = "mike.brown";  Group = "GRP_Finance" },
    @{ First = "Lisa";  Last = "White"; Username = "lisa.white";  Group = "GRP_HR" },
    @{ First = "Tom";   Last = "Davis"; Username = "tom.davis";   Group = "GRP_Sales" }
)

foreach ($user in $users) {
    New-ADUser -GivenName $user.First -Surname $user.Last `
        -Name "$($user.First) $($user.Last)" `
        -SamAccountName $user.Username `
        -UserPrincipalName "$($user.Username)@$domain" `
        -Path "OU=Lab Users,$domainDN" `
        -AccountPassword $password -Enabled $true -PasswordNeverExpires $true
    Add-ADGroupMember -Identity $user.Group -Members $user.Username
    Write-Host "Created: $($user.Username) -> $($user.Group)" -ForegroundColor Cyan
}
Write-Host "`nDone." -ForegroundColor Green