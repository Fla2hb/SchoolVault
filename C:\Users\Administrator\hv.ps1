Write-Host "=== HYPER-V VMs ==="
Get-VM | Select-Object Name, State, Uptime, Version | Format-Table -AutoSize
Write-Host "`n=== HOST NOTES ==="
Get-VMHost | Select-Object Name, Version, ManagementOS, HyperVSupportedVersion, IsStandardClusterEnabled | Format-Table -AutoSize
If (Get-Module -ListAvailable -Name Hyper-V) { Write-Host "Hyper-V module available" }
