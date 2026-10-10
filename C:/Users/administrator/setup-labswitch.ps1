$ErrorActionPreference = 'Stop'
Write-Host '=== Step 1: Create internal switch LabSwitch ==='
$sw = Get-VMSwitch -Name 'LabSwitch' -ErrorAction SilentlyContinue
if ($sw) {
    Write-Host ('Switch already exists: ' + $sw.Name)
    Write-Host ('SwitchType: ' + $sw.SwitchType)
} else {
    New-VMSwitch -Name 'LabSwitch' -SwitchType Internal
    Write-Host 'Created internal switch LabSwitch'
}
Start-Sleep -Seconds 3
Write-Host '=== Step 2: Create NAT on 192.168.50.0/24, gateway 192.168.50.1 ==='
$nat = Get-NetNat -Name 'LabSwitchNAT' -ErrorAction SilentlyContinue
if ($nat) {
    $nat | Remove-NetNat -Confirm:$false
    Start-Sleep -Seconds 2
}
New-NetNat -Name 'LabSwitchNAT' -InternalIPInterfaceAddressPrefix '192.168.50.0/24' | Out-Null
Write-Host 'Created NAT LabSwitchNAT'
Write-Host '=== Done ==='
