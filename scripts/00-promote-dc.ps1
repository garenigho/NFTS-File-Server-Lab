Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Write-Host "Installing AD DS..." -ForegroundColor Yellow
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

$safeModePassword = ConvertTo-SecureString 'SAFE_MODE_PASSWORD' -AsPlainText -Force
Import-Module ADDSDeployment

$params = @{
    DomainName                    = "lab.local"
    DomainNetbiosName             = "LAB"
    ForestMode                    = "WinThreshold"
    DomainMode                    = "WinThreshold"
    InstallDns                    = $true
    CreateDnsDelegation           = $false
    SafeModeAdministratorPassword = $safeModePassword
    NoRebootOnCompletion          = $true
    Force                         = $true
}
Install-ADDSForest @params

Write-Host "Promotion complete. Rebooting in 20 seconds..." -ForegroundColor Green
shutdown /r /t 20 /c "AD DS promotion complete"