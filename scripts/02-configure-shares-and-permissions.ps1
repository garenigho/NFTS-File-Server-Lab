Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

$domain   = "LAB"
$basePath = "C:\Shares"

New-Item -Path $basePath -ItemType Directory -Force | Out-Null

foreach ($folder in @("Finance", "HR", "Sales", "IT")) {
    New-Item -Path "$basePath\$folder" -ItemType Directory -Force | Out-Null
    if (-not (Get-SmbShare -Name $folder -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name $folder -Path "$basePath\$folder" -FullAccess "Everyone" | Out-Null
    }
    Write-Host "Share ready: $folder" -ForegroundColor Yellow
}

function Set-FolderPermissions {
    param($path, $permissions)
    icacls $path /inheritance:d | Out-Null
    icacls $path /remove "BUILTIN\Users" | Out-Null
    icacls $path /remove "Everyone" | Out-Null
    icacls $path /remove "NT AUTHORITY\Authenticated Users" | Out-Null
    foreach ($p in $permissions) {
        $identity = $p.Identity
        $rights   = $p.Rights
        icacls $path /grant "${identity}:${rights}"
    }
}

Set-FolderPermissions -path "$basePath\Finance" -permissions @(
    @{ Identity = "$domain\GRP_Finance";      Rights = "(OI)(CI)M" },
    @{ Identity = "$domain\GRP_HR";           Rights = "(OI)(CI)R" },
    @{ Identity = "$domain\GRP_IT";           Rights = "(OI)(CI)F" },
    @{ Identity = "BUILTIN\Administrators";   Rights = "(OI)(CI)F" }
)
Set-FolderPermissions -path "$basePath\HR" -permissions @(
    @{ Identity = "$domain\GRP_HR";           Rights = "(OI)(CI)M" },
    @{ Identity = "$domain\GRP_IT";           Rights = "(OI)(CI)F" },
    @{ Identity = "BUILTIN\Administrators";   Rights = "(OI)(CI)F" }
)
Set-FolderPermissions -path "$basePath\Sales" -permissions @(
    @{ Identity = "$domain\GRP_Sales";        Rights = "(OI)(CI)M" },
    @{ Identity = "$domain\GRP_IT";           Rights = "(OI)(CI)F" },
    @{ Identity = "BUILTIN\Administrators";   Rights = "(OI)(CI)F" }
)
Set-FolderPermissions -path "$basePath\IT" -permissions @(
    @{ Identity = "$domain\GRP_IT";           Rights = "(OI)(CI)F" },
    @{ Identity = "BUILTIN\Administrators";   Rights = "(OI)(CI)F" }
)

Write-Host "`nDone." -ForegroundColor Cyan