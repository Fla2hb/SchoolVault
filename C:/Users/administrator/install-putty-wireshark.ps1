$ErrorActionPreference = 'Stop'
Write-Host '=== Installing PuTTY ==='
winget install --id PuTTY.PuTTY --source winget --accept-package-agreements --silent --disable-interactivity
Write-Host ('PuTTY_EXIT_CODE=' + $LASTEXITCODE)

Write-Host '=== Installing Wireshark ==='
winget install --id WiresharkFoundation.Wireshark --source winget --accept-package-agreements --silent --disable-interactivity
Write-Host ('Wireshark_EXIT_CODE=' + $LASTEXITCODE)
