Write-Host "=== DOMAIN ==="
Get-ADDomain -Status -Properties DistinguishedName | Format-List -AutoSize
Write-Host "`n=== DOMAIN CONTROLLERS ==="
Get-ADDomainController -Filter * | Select-Object HostName, IPv4Address, Site, OperationMasterRole | Format-Table -AutoSize
Write-Host "`n=== FSMO ROLES (netdom) ==="
netdom query fsmo 2>&1
Write-Host "`n=== DNS (if applicable) ==="
nslookup lab.local 2>&1 | head -20
