# Decommission Plan — WINTHIRTYSIX (lab.local)

**Host:** WINTHIRTYSIX
**Domain:** lab.local (forest: lab.local) — **Active Directory Domain Controller (only DC, holds all 5 FSMO roles)**
**OS:** Windows Server 2025 Standard, Build 26100 (10.0.26100), 64-bit
**RAM:** ~16.78 GB total; ~5.56 GB free
**Backup drive:** E: — NTFS, 95.51 GB total, **42.48 GB free**, 44.48% free
**Lab tools:** Obsidian (vault C:\Users\Administrator\SchoolVault), Git for Windows, PuTTY, Wireshark+Npcap, WSL Ubuntu (Hermes Agent)
**Plan file:** `/mnt/c/Users/Administrator/SchoolVault/Final/Decommission-Plan.md`

> **Execution-order warning:** Hermes Agent runs **inside WSL**. Deleting WSL deletes Hermes (its config, SSH keys, `.git-credentials`, and the orchestration tooling). The DC demotion in Step 4 **reboots the server mid-session**. Steps that require the human to act directly in PowerShell are marked **[HUMAN]**. This is a **plan only — nothing is executed**.

---

## Step 0 — Pre-checks (read-only confirm, no changes)

**Purpose:** confirm the verified system state, that the GPO/file backups are on E:, that the plans were pushed to GitHub, and enumerate what becomes irreversible.

[Verification commands to run before starting:]

```powershell
# Confirm current state
Get-ComputerInfo | Select-Object CsName, OsVersion, CsDomain
Get-ADDomain -Status | Select-Object Name, Forest
Get-ADDomainController -Filter * | Select-Object HostName, Site
Get-GPO -All | Select-Object DisplayName, Id
Get-VM | Select-Object Name, State
wbadmin get versions -target:backup -quiet
git -C 'C:\Users\Administrator\SchoolVault' log --oneline -3
git -C 'C:\Users\Administrator\SchoolVault' remote -v
```

[Verification commands to run after starting:]

```powershell
# Confirm GPO backups present on E:
Get-ChildItem 'E:\GPOBackup' -Directory | Select-Object Name
Get-ChildItem 'E:\Backups' -Directory | Select-Object Name
# Confirm plans on GitHub
git -C 'C:\Users\Administrator\SchoolVault' ls-remote --get-url origin
```

**Irreversible items:**
- **lab.local is destroyed** — WINTHIRTYSIX is the *only* domain controller; demoting it (Step 4) removes the entire domain. No rollback except re-adding a fresh DC.
- **All 8 VM definitions and their VHDs** are deleted (Step 1) — data inside Alpine1–4, Manager1, node1–3 is gone.
- **Hot-added disk/USB data on C:** (e.g., dumps, seeds) is deleted with the folders in Step 3.
- **The GitHub repo, if deleted in Step 6**, is not recoverable from this machine (the local origin is the only copy until the remote mirror is rebuilt externally).
- **WSL Ubuntu + Hermes** — `wsl --unregister Ubuntu` deletes the entire Ubuntu installation, including the agent's config, SSH keys, and credential storage. This cannot be undone without an external backup.
- **E: contents** — any non-backup data on E: is wiped per the retention policy (Step 5).

**Status:** ☐ VMDisks backed up to E: ☐ GPO backups on E: ☐ Plans pushed to GitHub (Commit `1db8bd1`) ☐ E: free space ≥ 42 GB (42.48 GB) ☐ Confirmed server is the only DC

---

## Step 1 — Delete all VMs (safe / reversible until Remove-VM)

**Purpose:** remove all 8 VMs, all snapshots/checkpoints, and the virtual hard disks, configuration, and ISO files from C:\Hyper-V, C:\HyperV, and E:\vm server. `Get-VM` must be empty.

**Commands (run in an elevated PowerShell):**

```powershell
# 1) Stop all 8 VMs gracefully, then forcefully
$VMs = @('Alpine1','Alpine2','Alpine3','Alpine4','Manager1','node1','node2','node3')
foreach ($v in $VMs) {
  $vm = Get-VM -Name $v -ErrorAction SilentlyContinue
  if ($vm) {
    Write-Host "Stopping $v ..."
    Stop-VM -Name $v -Force -Confirm:$false -ErrorAction Stop
  }
}
Start-Sleep -Seconds 5

# 2) Remove all checkpoints (including any "new setup" checkpoint)
$VMs | ForEach-Object {
  $snaps = Get-VMSnapshot -VMName $_ -ErrorAction SilentlyContinue
  if ($snaps) {
    Write-Host "Removing checkpoints for $($_) : $($snaps.Count)"
    Remove-VMSnapshot -VMName $_ -Snapshot $_ -Confirm:$false -ErrorAction Stop
  }
}

# 3) Remove each VM
foreach ($v in $VMs) {
  $vm = Get-VM -Name $v -ErrorAction SilentlyContinue
  if ($vm) { Remove-VM -Name $v -Force -Confirm:$false -ErrorAction Stop }
}

# 4) Delete VHDX / ISO / config files under C:\Hyper-V, C:\HyperV, E:\vm server
Get-ChildItem -Path 'C:\Hyper-V','C:\HyperV','E:\vm server' -Recurse -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '\.(vhd(x?)|iso|vmrs?|vmcx?)$' -or $_.Name -match '\.(vsv|svsse)?$' } |
  Remove-Item -Recurse -Force -ErrorAction Continue

# Clean C:\Hyper-V and C:\HyperV top-level
Get-ChildItem 'C:\Hyper-V','C:\HyperV' -Directory -ErrorAction SilentlyContinue |
  Remove-Item -Recurse -Force -ErrorAction Continue
```

[Verification:]

```powershell
Get-VM | Select-Object Name, State   # must return nothing
Get-ChildItem 'C:\Hyper-V','C:\HyperV' -Directory | Select-Object Name  # must return nothing
Get-ChildItem 'E:\vm server' -Directory | Select-Object Name  # must return nothing
```

**Rollback / point of no return:** Deleting a VM definition is effectively irreversible (only a saved/active VM state could be recovered by re-importing from a backup). Stop at `Remove-VM` and confirm the list is empty before proceeding.

---

## Step 2 — Remove lab networking (safe / reversible until .wslconfig)

**Purpose:** remove the lab-specific Hyper-V switch, NAT, port proxy, firewall rule, and the WSL forwarding config that lets Hermes reach the lab.

[Commands (run in elevated PowerShell / Command Prompt):]

```cmd
:: 1) Delete the VM switch and NAT
Remove-VMSwitch -Name "LabSwitch" -Confirm:$false -ErrorAction Stop
netsh interface ip delete natservice "LabSwitchNAT"   2>nul
netsh interface portproxy reset                        2>nul

:: 2) Remove the firewall rule "Obsidian REST from LabSwitch"
netsh advfirewall firewall delete rule name="Obsidian REST from LabSwitch" 2>nul

:: 3) Disable interface forwarding (VM switch NIC forwarding)
netsh interface ipv4 set interface "LabSwitch" forwarding=disabled 2>nul
```

```powershell
# 4) Delete the WSL forwarding config (the file that lets Windows reach WSL)
if (Test-Path 'C:\Users\Administrator\.wslconfig') {
  Remove-Item 'C:\Users\Administrator\.wslconfig' -Force
  Write-Host "Deleted C:\Users\Administrator\.wslconfig"
}
```

**Verification:**

```powershell
Get-VMSwitch | Select-Object Name          # must be empty
Get-NetNat | Select-Object Name            # must be empty
netsh interface portproxy show all         # must be empty
netsh advfirewall firewall show rule name="Obsidian REST from LabSwitch" 2>nul
Test-Path 'C:\Users\Administrator\.wslconfig'  # must be $false
```

**Rollback / point of no return:** This is safe only until the `netsh interface portproxy reset` and `.wslconfig` deletion are run. If you need to reach the lab again, you must recreate the switch, NAT, and firewall rule, and rewrite `.wslconfig`. Do not run the next steps until you are certain you no longer need lab connectivity.

---

## Step 3 — Delete applications and files (safe / reversible until the drive is wiped)

**Purpose:** uninstall the lab applications, delete the data folders, and disable SMB1.

[Commands (run in elevated PowerShell):]

```powershell
# 1) Uninstall applications by display name / prog ID
Get-WmiObject Win32_Product | Where-Object { $_.Name -match 'Obsidian|Git|PuTTY|Wireshark|Npcap' } |
  ForEach-Object { $_.Uninstall() }

# Confirm (uses the proper MSI-based uninstaller via winget if available)
winget uninstall --name "Git for Windows" --id Git.Git --force 2>$null
winget uninstall --name "PuTTY" --id PuTTY.PuTTY --force 2>$null
winget uninstall --name "Wireshark" --id Wireshark.Wireshark --force 2>$null
winget uninstall --name "Npcap" --id Npcap.Npcap --force 2>$null
```

```powershell
# 2) Delete the data folders (SchoolVault, Shares, Software, GPOBackup, Temp, inetpub, Ubuntu, Downloads)
$paths = @(
  'C:\Users\Administrator\SchoolVault',
  'C:\Shares', 'C:\Software', 'C:\GPOBackup', 'C:\Temp',
  'C:\inetpub', 'C:\Users\Administrator\Downloads',
  'E:\ubuntu'
)
foreach ($p in $paths) {
  if (Test-Path $p) {
    Write-Host "Deleting $p ..."
    Remove-Item -Path $p -Recurse -Force -ErrorAction Stop
  }
}
```

```powershell
# 3) Disable SMB1 (coding, unless the role is already removed)
Disable-WindowsOptionalFeature -FeatureName SMB1Protocol -Online -NoRestart -Confirm:$false
```

**Verification:**

```powershell
Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol | Select-Object State
Get-WmiObject Win32_Product | Where-Object { $_.Name -match 'Obsidian|Git|PuTTY|Wireshark|Npcap' }
Get-ChildItem 'C:\Users\Administrator\SchoolVault','C:\Shares','C:\Software','C:\GPOBackup','C:\inetpub','E:\ubuntu' -ErrorAction SilentlyContinue | Select-Object FullName
```

**Rollback / point of no return:** Deleting the folders and uninstalling the apps is irreversible. SMB1 cannot be re-enabled without a reboot. If you need any of these applications or directories again, you must reinstall from scratch. Proceed only after Step 3 is complete.

---

## Step 4 — Demote the domain controller [HUMAN — point of no return]

**Purpose:** remove WINTHIRTYSIX from the domain. Because it is the *only* DC for `lab.local`, this **destroys the entire lab domain** (its OS, AD DS, DNS, SYSVOL, and the computer account). This is the irreversible step.

> The **HUMAN** must type the **new local administrator password** when prompted. Never the AI. The server will **reboot** mid-session.

[Commands (run in an elevated PowerShell; the human types the password when prompted):]

```powershell
# Point of no return — demote this server as the last DC
Uninstall-ADDSDomainController -LastDomainControllerInDomain -RemoveApplicationPartitions `
  -IgnoreLastDNSServerForZone -DemoteOperationMasterRole -Confirm:$false
```

If prompted for the new local administrator password, the HUMAN types it. The command reboots the server. After reboot, re-open an administrative PowerShell session.

```powershell
# 2) After demotion, remove remaining AD-related roles
Get-WindowsFeature -Name 'AD-Domain-Services','DNS','GPMC','Hyper-V' | Where-Object { $_.Installed } |
  Uninstall-WindowsFeature -Remove -Confirm:$false

# 3) Verify the server is now in a workgroup
Get-ComputerInfo | Select-Object CsName, CsDomain
```

Verify with **Windows Settings → System → About → Workgroup** (should be `WORKGROUP`, not `lab.local`), or via:

```powershell
(netdom query dnsdomainname 2>nul) ; (Get-ComputerInfo).CsDomain
```

**Rollback / point of no return:** Once `Uninstall-ADDSDomainController` completes, `lab.local` is permanently destroyed. The OU, GPOs, AD structure, and all domain accounts are gone. There is no rollback without building a new DC from scratch. This is the **single most destructive command in this plan**.

---

## Step 5 — Remove traces (read-only to the server; the final wipe)

**Purpose:** remove backups per retention policy, unregister WSL (deletes Hermes), remove leftover credentials/event logs, empty the Recycle Bin, and securely wipe C: and E:.

[Commands (run in an elevated PowerShell):]

```powershell
# 1) Backups: keep offsite OR securely wipe E:\Backups and E:\WindowsImageBackup
#    Option A (keep offsite): skip the wipe. Verify no leftover lab data remains.
Get-ChildItem 'E:\Backups','E:\WindowsImageBackup' -Recurse -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'lab|WINTHIRTYSIX|AD-SystemState' } | Select-Object FullName

#    Option B (securely wipe): run only if no offsite copy exists
# cipher /w is the Windows native secure-erase utility
cipher /w:C:\ 2>nul
cipher /w:E:\ 2>nul
```

```powershell
# 2) Unregister WSL (this deletes Hermes, its config, SSH keys, ~/.git-credentials)
wsl --unregister Ubuntu
```

```powershell
# 3) Remove WSL feature from Windows
Disable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online -NoRestart -Confirm:$false
```

```powershell
# 4) Delete leftover credentials / login entries
cmdkey /list
# (HUMAN: inspect output, then delete each entry; no automated delete is safe here)
```

```powershell
# 5) Clear event logs, empty the Recycle Bin, remove extra profiles
Get-EventLog -LogName Application -Source * -ErrorAction SilentlyContinue | ForEach-Object { Clear-EventLog -LogName $_.LogName }
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
# (HUMAN: remove any additional local user profiles; list them first)
Get-CimInstance Win32_UserProfile | Select-Object LocalPath, Status
```

**Verification:**

```powershell
wsl --list --verbose          # must be empty
(Get-Command wsl).Source       # should no longer exist
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux | Select-Object State
netsh advfirewall firewall show rule name="Obsidian REST from LabSwitch" 2>nul | Select-Object -First 1
(Get-ComputerInfo).CsDomain   # should be WORKGROUP
```

**Rollback / point of no return:** `wsl --unregister Ubuntu` and `cipher /w` are irreversible. If you need Hermes again, you would have to reinstall WSL + a fresh Ubuntu and re-provision authentication. Only run these when every other step is confirmed complete.

---

## Step 6 — Revoke external credentials (human, outside the server)

**Purpose:** remove GitHub PAT, Hermes model API key, and the Obsidian REST API key (already reset in the lab).

[What the human must do, outside the server:]

1. **GitHub:** revoke the personal access token (PAT) used for `git push` and `git clone`. Delete it from GitHub Settings → Developer settings → Personal access tokens.
2. **Hermes model API key:** delete the key from the model provider's console (this machine's config is inside WSL/Ubuntu and will be destroyed in Step 5).
3. **Obsidian REST API key:** already reset in `C:\Users\Administrator\obsidian-mcp.env` (notebook) — confirm the key value in that file is no longer in use.
4. **Decide:** archive or delete the GitHub repo `Fla2hb/SchoolVault`. If you delete it, the backups on E: become the only local copy (Step 5). If you keep it, note that a secret was committed to Git history earlier — see below.

**Secret in Git history:** a secret was committed to Git history earlier. To remove it permanently, either:
- Run `git filter-repo` (or `git filter-branch`) to rewrite history and force-push, or
- Alternatively, simply **delete the repo** and re-clone if you do not need the history.

If you choose to keep the repo, you must rewrite history to remove the secret:

```bash
# (run on the machine that has local access to the repo, outside the server)
git filter-repo --invert-paths --path '<path-containing-secret>'
git push --force
```

**Rollback / point of no return:** revoking credentials and deleting the repo are irreversible actions that affect accounts *outside* this server. Once the local machine is decommissioned, you cannot re-read these secrets from the server.

---

## Step 7 — Final verification checklist and shutdown

**Purpose:** confirm every item is removed and then shut down the server.

[Commands (run in an elevated PowerShell) — this is the final verification:]

```powershell
Write-Host "=== VMs ==="; Get-VM | Select-Object Name, State; if (-not (Get-VM)) { Write-Host "OK: no VMs" }
Write-Host "=== Roles ==="; Get-WindowsFeature | Where-Object { $_.Installed -and $_.Name -in 'AD-Domain-Services','DNS','GPMC','Hyper-V','File-Services','Storage-Services','SMB1' } | Select-Object Name; if (-not (Get-WindowsFeature | Where-Object { $_.Installed -and $_.Name -in 'AD-Domain-Services','DNS','GPMC','Hyper-V','File-Services','Storage-Services','SMB1' })) { Write-Host "OK: roles removed" }
Write-Host "=== Group Policy ==="; Get-GPO -All -ErrorAction SilentlyContinue; if (-not (Get-GPO -All)) { Write-Host "OK: no GPOs" }
Write-Host "=== Hyper-V switch ==="; Get-VMSwitch | Select-Object Name; if (-not (Get-VMSwitch)) { Write-Host "OK: no switch" }
Write-Host "=== NAT ==="; Get-NetNat | Select-Object Name; if (-not (Get-NetNat)) { Write-Host "OK: no NAT" }
Write-Host "=== PortProxy ==="; netsh interface portproxy show all 2>nul; if (-not (netsh interface portproxy show all 2>nul)) { Write-Host "OK: no portproxy" }
Write-Host "=== Firewall rule ==="; netsh advfirewall firewall show rule name="Obsidian REST from LabSwitch" 2>nul | Select-Object -First 1; if (-not (netsh advfirewall firewall show rule name="Obsidian REST from LabSwitch" 2>nul)) { Write-Host "OK: no firewall rule" }
Write-Host "=== WSL ==="; wsl --list --verbose 2>nul; if (-not (wsl --list --verbose 2>nul)) { Write-Host "OK: no WSL" }
Write-Host "=== Domain ==="; (netdom query dnsdomainname 2>nul); if ((netdom query dnsdomainname 2>nul) -eq '') { Write-Host "OK: workgroup" }
Write-Host "=== SMB1 ==="; Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol | Select-Object -ExpandProperty State; if ((Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol).State -eq 'Disabled') { Write-Host "OK: SMB1 disabled" }
Write-Host "=== Apps ==="; Get-WmiObject Win32_Product | Where-Object { $_.Name -match 'Obsidian|Git|PuTTY|Wireshark|Npcap' }; if (-not (Get-WmiObject Win32_Product | Where-Object { $_.Name -match 'Obsidian|Git|PuTTY|Wireshark|Npcap' })) { Write-Host "OK: apps uninstalled" }
Write-Host "=== Folders ==="; Get-ChildItem 'C:\Users\Administrator\SchoolVault','C:\Shares','C:\Software','C:\GPOBackup','C:\inetpub','E:\ubuntu' -ErrorAction SilentlyContinue | Select-Object FullName; if (-not (Get-ChildItem 'C:\Users\Administrator\SchoolVault','C:\Shares','C:\Software','C:\GPOBackup','C:\inetpub','E:\ubuntu' -ErrorAction SilentlyContinue)) { Write-Host "OK: folders removed" }
Write-Host "=== Credentials ==="; cmdkey /list; if (-not (cmdkey /list)) { Write-Host "OK: no credentials" }
```

If **all** of the above print `OK:` lines, power off the server:

```powershell
Stop-Computer -Force
```

The server will shut down (or you will be prompted to confirm). This is the intended end state.

**Rollback / point of no return:** Once `Stop-Computer` is issued, the machine is offline and no further verification or work can be done from it.

---

## Summary of execution-order and who does each step

| Step | Action | Who |
|---|---|---|
| 0 | Pre-checks (read-only) | AI |
| 1 | Delete VMs + VHDs | AI (escalate if a prompt requires confirmation) |
| 2 | Remove lab networking | AI |
| 3 | Delete apps / files + disable SMB1 | AI |
| 4 | Demote DC (reboots mid-session) | **[HUMAN]** types the new local admin password |
| 5 | Wipe backups, unregister WSL, wipe C:/E: | AI (escalate on wipe commands) |
| 6 | Revoke external credentials (GitHub PAT, Hermes API key) | **[HUMAN]** |
| 7 | Final verification checklist + `Stop-Computer` | AI / Human confirmation |

**Git commit at the end (run from the server, in an elevated session):**

```cmd
cd /mnt/c/Users/Administrator/SchoolVault
git status
git add ONLY "Final/Decommission-Plan.md" by name   (never git add -A)
git commit -m "Final: decommission plan"
git push
```

Show `git status` and the push output after the commit.
