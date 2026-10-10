$ErrorActionPreference = 'SilentlyContinue'
Write-Host '=== Existing NATs ==='
Get-NetNat -ErrorAction SilentlyContinue | Format-Table -AutoSize

Write-Host '=== Existing vEthernet (Virtual Switch) adapters ==='
Get-NetAdapter -InterfaceDescription '*Virtual Switch*' -ErrorAction SilentlyContinue | Format-Table -AutoSize

Write-Host '=== IPv4 routes that look like NAT ranges (192.168/16, 172.16/12) ==='
Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.DestinationPrefix -like '192.168.*' -or $_.DestinationPrefix -like '172.16.*' } |
  Format-Table -AutoSize

Write-Host '=== Host IP addresses ==='
Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Format-Table -AutoSize
