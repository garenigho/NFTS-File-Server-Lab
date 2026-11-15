param(
    [Parameter(Mandatory = $true)][string]$KeyVaultName,
    [string]$ResourceGroup = "RG-FileServerLab"
)

$startTime = Get-Date
$scriptDir = Join-Path $PSScriptRoot "scripts"

function Log($msg, $color = "Cyan") {
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] $msg" -ForegroundColor $color
}

Log "Retrieving credentials from Key Vault..."
$AdminPassword = az keyvault secret show --vault-name $KeyVaultName --name "vm-admin-password" --query "value" -o tsv
if (-not $AdminPassword -or $LASTEXITCODE -ne 0) {
    throw "Could not retrieve password from Key Vault. Run az login first."
}
$AdminPassword = $AdminPassword.Trim()
Write-Host "  Credentials retrieved." -ForegroundColor Green

function Invoke-VMScript {
    param(
        [string]$VMName,
        [string]$ScriptFile,
        [string]$Description,
        [hashtable]$Replacements = @{}
    )
    Log ">>> $Description ($VMName)"
    $script = Get-Content (Join-Path $scriptDir $ScriptFile) -Raw
    foreach ($key in $Replacements.Keys) {
        $script = $script.Replace($key, $Replacements[$key])
    }
    $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + ".ps1")
    Set-Content -Path $tempFile -Value $script -Encoding ASCII
    try {
        $json = az vm run-command invoke --resource-group $ResourceGroup --name $VMName `
            --command-id RunPowerShellScript --scripts "@$tempFile" --output json --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "az vm run-command failed on $VMName" }
        $result = ($json -join "`n") | ConvertFrom-Json
        $stdout = ($result.value | Where-Object { $_.code -like "*StdOut*" }).message
        $stderr = ($result.value | Where-Object { $_.code -like "*StdErr*" }).message
        if ($stdout) { Write-Host $stdout }
        if ($stderr -and $stderr.Trim() -ne "") { Write-Warning "VM StdErr: $stderr" }
    }
    finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

function Wait-VMReady {
    param([string]$VMName, [int]$TimeoutSeconds = 900)
    Write-Host "  Letting $VMName start its reboot..." -ForegroundColor Yellow
    Start-Sleep -Seconds 45
    $elapsed = 45
    while ($elapsed -lt $TimeoutSeconds) {
        $out = az vm run-command invoke --resource-group $ResourceGroup --name $VMName `
            --command-id RunPowerShellScript --scripts "hostname" --output json --only-show-errors 2>$null
        if ($LASTEXITCODE -eq 0 -and $out) {
            Write-Host "  $VMName is answering again." -ForegroundColor Green
            return
        }
        Write-Host "    $VMName not ready yet ($elapsed s)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 15
        $elapsed += 15
    }
    throw "Timeout: $VMName did not come back within $TimeoutSeconds seconds."
}

Log "[STEP 1] Promoting DC01 to Domain Controller" "Magenta"
Invoke-VMScript -VMName "DC01" -ScriptFile "00-promote-dc.ps1" -Description "Promoting DC01" `
    -Replacements @{ "SAFE_MODE_PASSWORD" = $AdminPassword }
Wait-VMReady -VMName "DC01"
Start-Sleep -Seconds 60

Log "[STEP 2] Creating OUs, Groups, and Users" "Magenta"
Invoke-VMScript -VMName "DC01" -ScriptFile "01-create-ad-users-groups.ps1" -Description "Creating AD objects"

Log "[STEP 3] Joining FS01 to lab.local" "Magenta"
Invoke-VMScript -VMName "FS01" -ScriptFile "04-domain-join.ps1" -Description "Joining FS01" `
    -Replacements @{ "ADMIN_PASSWORD" = $AdminPassword }
Wait-VMReady -VMName "FS01"

Log "[STEP 4] Configuring shares and NTFS on FS01" "Magenta"
Invoke-VMScript -VMName "FS01" -ScriptFile "02-configure-shares-and-permissions.ps1" -Description "Creating shares and NTFS"

Log "[STEP 5] Joining CLIENT01 to lab.local" "Magenta"
Invoke-VMScript -VMName "CLIENT01" -ScriptFile "04-domain-join.ps1" -Description "Joining CLIENT01" `
    -Replacements @{ "ADMIN_PASSWORD" = $AdminPassword }
Wait-VMReady -VMName "CLIENT01"

Log "[STEP 5b] Granting Domain Users RDP on CLIENT01" "Magenta"
Invoke-VMScript -VMName "CLIENT01" -ScriptFile "06-add-rdp-users.ps1" -Description "Adding Domain Users to RDP group"

Log "[STEP 6] Configuring RDP GPO on DC01" "Magenta"
Invoke-VMScript -VMName "DC01" -ScriptFile "03-configure-rdp-gpo.ps1" -Description "Creating RDP GPO"

Log "[STEP 7] Running automated verification" "Magenta"
Invoke-VMScript -VMName "DC01" -ScriptFile "05-verify-ad.ps1" -Description "Verifying AD"
Invoke-VMScript -VMName "FS01" -ScriptFile "05-verify-shares.ps1" -Description "Verifying shares"

$duration = (Get-Date) - $startTime
Write-Host "`n=== LAB FULLY CONFIGURED ($([math]::Round($duration.TotalMinutes,1)) min) ===" -ForegroundColor Green
Write-Host "RDP into CLIENT01 as: LAB\sarah.jones   Password: P@ssw0rd123!"