Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$basePath = "C:\Shares"
$pass = $true
$FSR = [System.Security.AccessControl.FileSystemRights]

Write-Host "`n=== Share and NTFS Verification ===" -ForegroundColor Cyan

$expectedACLs = [ordered]@{
    "Finance" = @(
        @{ Identity = "LAB\GRP_Finance"; Right = $FSR::Modify },
        @{ Identity = "LAB\GRP_HR";      Right = $FSR::Read },
        @{ Identity = "LAB\GRP_IT";      Right = $FSR::FullControl }
    )
    "HR" = @(
        @{ Identity = "LAB\GRP_HR"; Right = $FSR::Modify },
        @{ Identity = "LAB\GRP_IT"; Right = $FSR::FullControl }
    )
    "Sales" = @(
        @{ Identity = "LAB\GRP_Sales"; Right = $FSR::Modify },
        @{ Identity = "LAB\GRP_IT";    Right = $FSR::FullControl }
    )
    "IT" = @(
        @{ Identity = "LAB\GRP_IT"; Right = $FSR::FullControl }
    )
}

foreach ($share in $expectedACLs.Keys) {
    Write-Host "`n[ $share ]" -ForegroundColor White

    $smb = Get-SmbShare -Name $share -ErrorAction SilentlyContinue
    if ($smb) { Write-Host "  [PASS] SMB share exists" -ForegroundColor Green }
    else { Write-Host "  [FAIL] Share missing" -ForegroundColor Red; $pass = $false; continue }

    $acl = (Get-Acl "$basePath\$share").Access
    foreach ($expected in $expectedACLs[$share]) {
        $ace = $acl | Where-Object {
            $_.IdentityReference.Value -eq $expected.Identity -and $_.AccessControlType -eq "Allow"
        }
        if (-not $ace) {
            Write-Host "  [FAIL] $($expected.Identity) has no entry" -ForegroundColor Red
            $pass = $false
            continue
        }
        $hasRight = (([int]$ace.FileSystemRights -band [int]$expected.Right) -eq [int]$expected.Right)
        if ($hasRight) {
            Write-Host "  [PASS] $($expected.Identity) -> $($expected.Right)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $($expected.Identity) wrong rights" -ForegroundColor Red
            $pass = $false
        }
    }
}

$result = if ($pass) { "PASSED" } else { "FAILED" }
$color  = if ($pass) { "Green" } else { "Red" }
Write-Host "`n=== Verification $result ===" -ForegroundColor $color