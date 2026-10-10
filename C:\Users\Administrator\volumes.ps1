$ErrorActionPreference = 'Stop'
Write-Host "=== GPOBackup GUID child ==="
Get-ChildItem 'C:\GPOBackup' -ErrorAction SilentlyContinue | ForEach-Object {
  $o = Get-ChildItem $_.FullName -ErrorAction SilentlyContinue
  Write-Host "$($_.Name) -> inner items:`n$($o | Select-Object Name, @{n='SizeGB';e={(Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum/1GB}} | Format-Table -AutoSize)"
}
Write-Host "`n=== E:\WindowsImageBackup (top-level + first site) ==="
Get-ChildItem 'E:\WindowsImageBackup' -ErrorAction SilentlyContinue | Select-Object Name, @{n='SizeGB';e={(Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum/1GB}} | Sort-Object Name | Format-Table -AutoSize
if (Get-ChildItem 'E:\WindowsImageBackup' -Directory -ErrorAction SilentlyContinue) {
  $s = Get-ChildItem 'E:\WindowsImageBackup' -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
  Write-Host "First site dir: $($s.Name)"
  Get-ChildItem $s.FullName -ErrorAction SilentlyContinue | Select-Object Name, @{n='SizeGB';e={(Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum/1GB}} | Format-Table -AutoSize | Out-String
}
Write-Host "`n=== E:\Backups subfolder contents (top-level each) ==="
Get-ChildItem 'E:\Backups\' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Host "[$($_.Name)]"
  Get-ChildItem $_.FullName -ErrorAction SilentlyContinue | Select-Object Name, @{n='SizeGB';e={(Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum/1GB}} | Sort-Object Name | Format-Table -AutoSize | Out-String
}
Write-Host "`n=== DNS zones (explicit, empty = none) ==="
Get-DnsServerZone -ErrorAction SilentlyContinue | Select-Object Name, State
Write-Host "Count: $(@(Get-DnsServerZone -ErrorAction SilentlyContinue).Count)"
Write-Host "`n=== AD site / subnets ==="
Get-ADReplicationSite -Filter * | Select-Object Name | Format-Table -AutoSize
Write-Host "`n=== GPO reports exist? ==="
Get-ChildItem 'C:\GPOBackup' -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\.(html|xml)$' } | Select-Object FullName, Name | Format-Table -AutoSize
