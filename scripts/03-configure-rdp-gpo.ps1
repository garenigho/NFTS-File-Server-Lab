Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

if (-not (Get-Module -ListAvailable -Name GroupPolicy)) {
    Install-WindowsFeature -Name GPMC | Out-Null
}
Import-Module GroupPolicy
Import-Module ActiveDirectory

$gpoName = "Lab - Allow RDP for Domain Users"
$ouPath  = "OU=Lab Computers,DC=lab,DC=local"

if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
    New-GPO -Name $gpoName | Out-Null
    New-GPLink -Name $gpoName -Target $ouPath | Out-Null
}

Set-GPRegistryValue -Name $gpoName `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" `
    -ValueName "fDenyTSConnections" -Type DWord -Value 0 | Out-Null

$computer = Get-ADComputer -Filter "Name -eq 'CLIENT01'" -ErrorAction SilentlyContinue
if ($computer) {
    $computer | Move-ADObject -TargetPath $ouPath
    Write-Host "Moved CLIENT01 to Lab Computers OU." -ForegroundColor Cyan
} else {
    Write-Warning "CLIENT01 not found in AD. It may not have joined yet."
}

Write-Host "`nGPO configuration complete." -ForegroundColor Green