# Backup Plan — WINTHIRTYSIX (lab.local)

**Host:** WINTHIRTYSIX
**Domain:** lab.local (forest: lab.local) — **Active Directory Domain Controller (only DC)**
**OS:** Windows Server 2025 Standard, Build 26100 (10.0.26100), 64-bit
**RAM:** ~16.78 GB total; ~5.56 GB free
**Hyper-V host:** WINTHIRTYSIX (standalone, no cluster)
**Backup destination:** **E:** (secondary drive — NTFS, 95.51 GB total, **42.48 GB free**, 44.48%)
**Plan file:** `/mnt/c/Users/Administrator/SchoolVault/Backup-Plan.md`

---

## 1. Environment Inventory

### Disks & Volumes

| Drive | FileSystem | Type | Size | Free | % Free | Notes |
|-------|-----------|------|------|------|--------|-------|
| (none) | FAT32 | Fixed | 205 MB | 170 MB | 83% | hidden/removable |
| D: | Unknown | CD-ROM | 7.57 GB | 0 B | 0% | empty optical |
| C: | NTFS | Fixed | 95.60 GB | 5.99 GB | **6.27%** | system drive (small, nearly full) |
| (none) | NTFS | Fixed | 810 MB | 152 MB | 18.7% | hidden |
| **E:** | NTFS | Fixed | 95.51 GB | **42.48 GB** | **44.48%** | **SECONDARY DRIVE — backup target** |
| (none) | FAT32 | Fixed | 1.12 GB | 1.12 GB | 100% | hidden |

- **Physical disks:** Disk 0 (4 partitions, 90.00 GB) and Disk 1 (2 partitions, 90.00 GB) — both Healthy.
- **Secondary drive = E:** has 42.48 GB free. All backups in this plan are written to **E:**.

### Roles & Features (installed, with `*` = enabled)

- **AD-Domain-Services** — Active Directory Domain Services ✅
- **DNS** — DNS Server ✅
- **FileAndStorage-Services, File-Services, FS-FileServer** — File Server ✅
- **Storage-Services** ✅
- **Hyper-V** ✅
- **GPMC** — Group Policy Management ✅
- **Windows Server Backup** ✅
- **.NET Framework 4.8** (45-Features, 45-Core) ✅
- **.NET WCF Services 45** ✅
- **MSMQ** ✅
- **Windows Defender** ✅
- **Storage-Replica** ✅
- **FS-SMB1** (SMB 1.0/CIFS) — enabled ⚠️ (disable if no legacy client needs it)
- **Windows Admin Center Setup** ✅
- **RAS / DirectAccess / Routing / RemoteAccess** — Available (not enabled)
- **WSUS** — Available (not listed as Installed); kept as-is unless WSUS role is brought online.

### Active Directory

- **Domain:** lab.local (forest: lab.local), DomainMode **Windows2025Domain**
- **Only domain controller:** `winthirtysix.lab.local` (192.168.50.1), Site: **Default-First-Site-Name**
- **This server IS the domain controller.** It holds **all five FSMO roles** (single-DC forest → all masters on the one DC):

| FSMO Role | Master |
|-----------|--------|
| Schema master | winthirtysix.lab.local |
| Domain naming master | winthirtysix.lab.local |
| PDC | winthirtysix.lab.local |
| RID pool manager | winthirtysix.lab.local |
| Infrastructure master | winthirtysix.lab.local |

- **DNS zones:** none defined (Active Directory-integrated zones are empty).
- **Tools available:** Get-GPO, Get-ADDomainController, netdom, dcdiag, gpresult, wbadmin (all confirmed installed).

### Group Policy Objects (Get-GPO -All)

| # | DisplayName | Id | Created |
|---|-------------|----|---------|
| 1 | Default Domain Policy | 31b2f340-016d-11d2-945f-00c04fb984f9 | 2026-09-17 |
| 2 | HR - Block Control Panel | 4903f528-3af6-4752-bc4f-c2478e8d9ebb | 2026-09-17 |
| 3 | Software Deployment | 543c9d93-5c6d-4347-ba62-66825df26149 | 2026-09-19 |
| 4 | Payroll - Block PowerShell | 5feb13ee-9a55-4607-9953-9d0583a04d40 | 2026-09-17 |
| 5 | Default Domain Controllers Policy | 6ac1786c-016f-11d2-945f-00c04fb984f9 | 2026-09-17 |
| 6 | New Group Policy Object | cb31a576-d1b5-411a-ba80-2e2a1c146a74 | 2026-09-17 |

- There is a **pre-existing** backup under `C:\GPOBackup\<GUID>\` from a prior manual `Backup-GPO` run, each containing `Backup.xml` + `gpreport.xml`.

### Hyper-V VMs (8)

| Name | State | Memory (startup) | Procs | Dynamic Memory | Notes |
|------|-------|------------------|-------|----------------|-------|
| Alpine1 | Running | 2 GB | 1 | No | |
| Alpine2 | Off | 1 GB | 1 | No | |
| Alpine3 | Off | 1 GB | 1 | No | |
| Alpine4 | Running | 2 GB | 1 | No | |
| Manager1 | Off | 2 GB | 1 | No | |
| node1 | Off | 2 GB | 1 | No | |
| node2 | Off | 2 GB | 1 | No | |
| node3 | Off | 2 GB | 1 | No | |

- **VM config / snapshot / VHD storage:** `C:\Hyper-V\` (folders: Manager1, node1, node2, node3), `C:\Hyper-V\Virtual Hard Disks`, `C:\Hyper-V\Snapshots`, `C:\Hyper-V\Virtual Machines`. The default in-memory VM path is `C:\ProgramData\Microsoft\Windows\Virtual Hard Disks`.
- **Total VM config on disk:** ~11.84 GB under `C:\Hyper-V\`.

### Key Data Folders

| Path | Current size | Notes |
|------|--------------|-------|
| `C:\Shares` | ~0 GB | File-share data root |
| `C:\Software` | 0.33 GB | Software packages |
| `C:\Hyper-V` | 11.84 GB | VM configs / VHDs |
| `C:\GPOBackup` | ~0 GB | GPO backup output (6 GUID subfolders) |
| `C:\Temp` | ~0 GB | Temp files |
| `C:\inetpub\` | (IIS root) | Web content |
| `E:\WindowsImageBackup` | 12.26 GB | BITS/Windows Image Backup (currently on E:) |
| `E:\vm server` | 22.60 GB | VM/server data |
| `E:\ubuntu` | 8.57 GB | Ubuntu VM/data |
| `E:\Backups` | sub-folders (AD_IFM, Files, GPO) | Backup staging area |

---

## 2. Backup Strategy Overview

All backups target **E:** (the secondary drive). The plan uses a **3-2-1** approach:

- **3 copies** of data (production + 2 backups)
- **2 different media** (primary internal storage + **offsite** copy — see §12)
- **1 offsite** copy (remote/cloud destination)

### Shape

| Job | Content | Frequency | Level | Destination |
|-----|---------|-----------|-------|-------------|
| **A. AD system state** | Active Directory system state (ntds.dit, SYSVOL, registry, boot config, Active Directory) | Daily | Full | `E:\Backups\AD\` |
| **B. File backup** | `C:\Shares`, `C:\Software`, `C:\Hyper-V`, `C:\GPOBackup`, `C:\Temp`, `C:\inetpub` | Daily | Incremental | `E:\Backups\Files\` |
| **C. GPO backup** | All 6 GPOs (Backup-GPO + .html reports) | Daily | Full | `E:\Backups\GPO\` |
| **D. Hyper-V export** | All 8 VMs (VMCX/VMRS + VHDs) | Daily | Full | `E:\Backups\HyperV\` |
| **E. Offsite copy** | Mirror of A–D to remote destination | After each successful local run | Mirror | Remote store |

---

## 3. File Backups

Use **Robocopy** for files (fast, incremental, resillient, logs to `E:\`) plus a Windows Server Backup (wbadmin) directory capture as the authoritative full snapshot.

### 3.1 Robocopy daily incremental (run via `C:\Backup\FileBackup.ps1`)

This copies data folders to `E:\Backups\Files\` and keeps a rolling mirror with versioned directories.

```powershell
# C:\Backup\FileBackup.ps1
$Source = @(
  'C:\Shares',
  'C:\Software',
  'C:\Hyper-V',
  'C:\GPOBackup',
  'C:\Temp',
  'C:\inetpub'
)
$Dest   = 'E:\Backups\Files\'
$LogDir = 'E:\Backups\Logs\'

foreach ($s in $Source) {
  $name = Split-Path $s -Leaf
  $today = Get-Date -Format 'yyyyMMdd'
  $runDir = Join-Path $Dest "$today"
  if (-not (Test-Path $runDir)) { New-Item -ItemType Directory -Path $runDir -Force | Out-Null }

  $args = @('/MIR','/XJ','/R:2','/W:5','/NP','/V','/LOG+:' + (Join-Path $LogDir "$name-$today.log"))
  robocopy $s $runDir $args
  Write-Host "Robocopy $s -> $runDir (exit=$?)"
}
```

- `/MIR` = mirror (enforces full sync).
- `/XJ` = exclude junctions (avoids loops).
- `/R:2 /W:5` = retry 2 times, wait 5 seconds (fast failure on busy locks).
- `/NP /V /LOG+` = no progress, verbose, log to file.

### 3.2 wbadmin directory capture (weekly full)

For an authoritative, single-point-in-time directory backup (similar to a system-state snapshot), run this weekly:

```cmd
wbadmin start backup -BackupTarget:E: -CaptureFile:E:\Backup\CaptureFiles\fileBackup.xml ^
  -Include:C:\Shares,C:\Software,C:\Hyper-V,C:\GPOBackup,C:\Temp,C:\inetpub ^
  -Version:1.0 -BackupId:FileBackup-Weekly -Description:"Weekly file backup" -AllowReboot
```

Create `E:\Backup\CaptureFiles\fileBackup.xml` with:

```xml
<Backup>
  <Home>
    <Directories>
      <Directory>C:\Shares</Directory>
      <Directory>C:\Software</Directory>
      <Directory>C:\Hyper-V</Directory>
      <Directory>C:\GPOBackup</Directory>
      <Directory>C:\Temp</Directory>
      <Directory>C:\inetpub</Directory>
    </Directories>
  </Home>
</Backup>
```

If you only ever need a full backup of the data folders (no incremental), replace `/MIR` above with a single robocopy mirror per folder.

---

## 4. Active Directory System State Backup (wbadmin)

This server is the **only DC** in `lab.local`. Its system-state backup is therefore critical — it is the domain itself.

**Run from an elevated PowerShell/Command Prompt.** The `-BackupTarget` must point at the secondary drive `E:`.

### 4.1 Daily system-state backup

```cmd
wbadmin start backup -BackupTarget:E: -IncludeSystemState -Version:1.0 -BackupId:AD-SystemState-Daily -Description:"AD system state daily" -AllowReboot
```

- `-IncludeSystemState` captures ntds.dit, SYSVOL, the registry, boot configuration, and Active Directory.
- The system must be able to reboot to complete the capture; `-AllowReboot` permits that. If you do not want the server to reboot, omit it — the capture will fail if the server restarts during backup.

### 4.2 Verify the system-state backup is present

```cmd
wbadmin get versions -target:backup -quiet
wbadmin get items -backupTarget:E: -ItemType:backup
```

Expected output shows `AD-SystemState-Daily` versions.

### 4.3 Restore a system-state backup (verify path)

```cmd
wbadmin start restore -BackupTarget:E: -Version:1.0 -ItemType:SYSTEMSTATE -RestoreTarget:C: -Confirm
```

Or restore to a different location to test without touching the live DC:

```cmd
wbadmin start restore -BackupTarget:E: -Version:1.0 -ItemType:SYSTEMSTATE -RestoreTarget:D:\TestRestore -Confirm
```

---

## 5. Group Policy Backups

### 5.1 Back up all GPOs (file + XML) to E:

```powershell
$gpOutput = Join-Path 'E:\Backups\GPO' (Get-Date -Format 'yyyyMMdd-HHmm')
New-Item -ItemType Directory -Path $gpOutput -Force | Out-Null

# 1) Backup each GPO (stores .xml backup files)
Get-GPO -All | ForEach-Object {
  Backup-GPO -Guid $_.Id -Path (Join-Path $gpOutput $_.DisplayName) -Description "Backup of $($_.DisplayName) on $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
  Write-Host "Backed up $($_.DisplayName)"
}

# 2) Generate GPO reports (HTML) for review/auditing
Get-GPO -All | ForEach-Object {
  $html = Join-Path $gpOutput "$($_.DisplayName).html"
  Get-GPOReport -Name $_.DisplayName -Path $html -ReportType Html
  Write-Host "Report written: $html"
}
```

### 5.2 Restore a GPO from backup

```powershell
Restore-GPO -BackupId 31b2f340-016d-11d2-945f-00c04fb984f9 -Domain lab.local -TargetName "Restored-Default-Domain-Policy" -Path "E:\Backups\GPO\Default Domain Policy"
```

### 5.3 Verify restore

```powershell
Get-GPO -Name "Restored-Default-Domain-Policy" -Domain lab.local | Select-Object DisplayName, Id, IsValid
```

### 5.4 Export GPO reports (machine-readable)

```powershell
Get-GPO -All | ForEach-Object {
  Get-GPOReport -Name $_.DisplayName -Path "E:\GPOBackup\$($_.DisplayName).xml" -ReportType Xml
}
```

---

## 6. Hyper-V VM Backups (exports)

Export each VM — this copies the `.vmcx`/`.vmrs` config files **and** the virtual hard disks to the target folder.

### 6.1 Export all VMs to E:

```powershell
$vmList = @('Alpine1','Alpine2','Alpine3','Alpine4','Manager1','node1','node2','node3')
$exportPath = 'E:\Backups\HyperV\'
New-Item -ItemType Directory -Path $exportPath -Force | Out-Null

foreach ($vm in $vmList) {
  if (Get-VM -Name $vm -ErrorAction SilentlyContinue) {
    Export-VM -Name $vm -Path (Join-Path $exportPath $vm) -Verify -Force
    Write-Host "Exported $vm"
  } else {
    Write-Warning "VM $vm not found"
  }
}
```

### 6.2 Export a specific VM

```powershell
Export-VM -Name "Alpine1" -Path "E:\Backups\HyperV\Alpine1" -Verify -Force
```

### 6.3 Restore a VM from an export

```powershell
Import-VM -Path "E:\Backups\HyperV\Alpine1" -GenerateNewID
```

### 6.4 Clean up old exports (retention governed by §8)

```powershell
Get-ChildItem 'E:\Backups\HyperV\' -Directory | Where-Object {
  $_.Name -notin @('Alpine1','Alpine2','Alpine3','Alpine4','Manager1','node1','node2','node3')
} | Remove-Item -Recurse -Force
```

---

## 7. Schedule

Assumed environment: the server runs continuously; backups run overnight to avoid user impact. Use **Task Scheduler** (or `schtasks`) with the triggers below.

### 7.1 Task schedule

| Task | Trigger | Action | User |
|------|---------------|--------|------|
| `AD-System-State-Daily` | Daily 02:00 | `wbadmin start backup -BackupTarget:E: -IncludeSystemState -Version:1.0 -BackupId:AD-SystemState-Daily` | LocalSystem |
| `File-Backup-Daily` | Daily 02:30 | `powershell C:\Backup\FileBackup.ps1` | LocalSystem |
| `GPO-Backup-Daily` | Daily 03:00 | `powershell C:\Backup\GPOBackup.ps1` | LocalSystem |
| `HyperV-Export-Daily` | Daily 03:30 | `powershell C:\Backup\HyperVExport.ps1` | LocalSystem |
| `Offsite-Copy` | Daily 04:00 (runs only after the four above succeed) | robocopy/mirror to remote | LocalSystem |
| `Verify-Restore-Test` | Weekly (Friday 06:00) | Perform a **test restore** of one AD, one GPO, and one VM (see §9) | LocalSystem |

### 7.2 Robocopy task definition (example)

```cmd
schtasks /Create /F /TN "AD-System-State-Daily" /TR "wbadmin start backup -BackupTarget:E: -IncludeSystemState -Version:1.0 -BackupId:AD-SystemState-Daily" /SC DAILY /ST 02:00 /RU SYSTEM
```

### 7.3 Log + exit-code handling (service-like behavior)

Wrap each PowerShell script with a wrapper that:
1. Logs start time to `E:\Backups\Logs\<task>-<date>.log`.
2. Captures the exit code of the underlying command.
3. If exit code is non-zero, writes a "FAILED" line and **sends an email/SMTP alert** (you will supply the SMTP config).
4. Logs end time.

Example wrapper head:

```powershell
$task = "AD-System-State-Daily"
$log = Join-Path 'E:\Backups\Logs' "$task-$(Get-Date -Format 'yyyyMMdd').log"
"START $(Get-Date -Format 'o')" | Out-File -FilePath $log -Append
& wbadmin start backup -BackupTarget:E: -IncludeSystemState -Version:1.0 -BackupId:AD-SystemState-Daily 2>&1 | Out-File -FilePath $log -Append
if ($LASTEXITCODE -ne 0) {
  "`nFAILED exit=$LASTEXITCODE" | Out-File -FilePath $log -Append
  # send alert email here
}
"END $(Get-Date -Format 'o')" | Out-File -FilePath $log -Append
```

---

## 8. Retention

Retention applies to the **secondary drive E:** (that is the backup media). After a restore test, **permanently delete the test artifacts** from the restore target.

### 8.1 Retention policy for E:

| Backup type | Keep newest copies |
|-------------|--------------------|
| Daily (system state + files + GPO + Hyper-V) | **30 daily** |
| Weekly full | **12 weekly** |
| Monthly archive | **12 monthly** |

This yields ~30 days of daily rollback + ~3 months of weekly + ~1 year of monthly.

### 8.2 Cleanup script (run monthly)

```powershell
# Keep 30 daily run folders, 12 weekly, 12 monthly under E:\Backups\Files
$files   = Get-ChildItem 'E:\Backups\Files\' | Sort-Object Name
$daily   = $files | Select-Object -Last 30
$files   = Get-ChildItem 'E:\Backups\HyperV\' | Sort-Object Name
$weekly  = $files | Select-Object -Last 12
$files   = Get-ChildItem 'E:\Backups\GPO\' | Sort-Object Name
$monthly = $files | Select-Object -Last 12

Get-ChildItem 'E:\Backups\Files\' | Where-Object { $_ -notin $daily } | Remove-Item -Recurse -Force
Get-ChildItem 'E:\Backups\HyperV\' | Where-Object { $_ -notin $weekly } | Remove-Item -Recurse -Force
Get-ChildItem 'E:\Backups\GPO\' | Where-Object { $_ -notin $monthly } | Remove-Item -Recurse -Force
```

- `wbadmin` versions on `E:` are automatically pruned per the policy you specify; set the retention policy explicitly so versions don't accumulate forever.

---

## 9. Restore Verification

A backup is only as good as its verified restore. Schedule a **test restore weekly** and record the results.

### 9.1 Verify a system-state restore

```cmd
wbadmin get items -backupTarget:E: -ItemType:backup
wbadmin start restore -BackupTarget:E: -Version:1.0 -ItemType:SYSTEMSTATE -RestoreTarget:C: -Confirm
```

Then confirm the restore by:
- Checking that `C:\Windows\System32\WindowsPowerShell\v1.0\...` date matches the backup.
- Reboot into **Safe Mode** and run `ntdsutil` / `dcdiag`:

```cmd
dcdiag /v
```

### 9.2 Verify a GPO restore

```powershell
# Confirm the GPO exists and is valid
Get-GPO -Name "Restored-Default-Domain-Policy" -Domain lab.local | Select-Object DisplayName, IsValid

# Confirm the .xml backup round-trips
Get-ChildItem "E:\Backups\GPO\Default Domain Policy\" -Filter *.xml
```

### 9.3 Verify a Hyper-V restore

```powershell
# List the exported VM
Get-ChildItem "E:\Backups\HyperV\Alpine1\" -Recurse | Select-Object Name, @{n='SizeGB';e={($_.Length/1GB).ToString('F2')}}

# Import test
Import-VM -Path "E:\Backups\HyperV\Alpine1" -GenerateNewID -Copy
```

### 9.4 Record-keeping

Log every successful restore test with:
- Date/time
- What was restored (AD system state / GPO / VM + name)
- Confirmation commands run and their output
- Pass/fail

A weekly log file must be maintained at `E:\Backups\Logs\RestoreTests-<date>.log`.

---

## 10. Verification Checklist (before the plan goes live)

1. **Run each job once manually** and confirm the artifacts land on `E:`.
2. **Check free space** on `E:` again after a simulated full run (system state + files + GPO + Hyper-V may total ~20–30 GB; confirm it still fits).
3. **Verify wbadmin** can read back the version list.
4. **Perform a restore test** (AD system state to a scratch folder, restore one GPO, import one VM) and log the result.
5. **Confirm the offsite copy step** (§12) can replicate `E:` to the remote store.

---

## 11. Notes, Constraints, and Known Edge Cases

- **C: is nearly full (6.27% free).** Do **not** back up the full `C:` drive. Back up only the data folders listed in §3. If you ever need a full-C: backup, first enlarge C: or move Pagefile/Swap to E:.
- **D: is a CD-ROM (empty).** Do not use it as a backup target.
- **This is a single-DOMAIN CONTROLLER** deployment. The AD system-state backup is the most valuable item in this plan — its loss would mean loss of the entire domain.
- **`Get-DnsServerZone` returned zero zones** — there are no Active Directory-integrated DNS zones defined. Verify DNS zone data separately if needed.
- **SMB1 is enabled** (`FS-SMB1` installed). Disable it unless a legacy client depends on it.
- **The backup scripts assume PowerShell is run as Administrator** (required for wbadmin, Hyper-V cmdlets, and clearing protected file attributes).
- **Hyper-V memory:** VMs have 1–2 GB static RAM each but none use dynamic memory — the total VM workload is small (~16 GB max if all run).
- **E: has 42.48 GB free.** Three daily jobs (system state ~12 GB + files + GPO + Hyper-V ~4–6 GB) can fit. The monthly archive is a copy, not a second live backup, so keep the archive count low.

---

## 12. 3-2-1 Offsite Copy

**3-2-1 rule:** 3 copies of your data, on 2 different types of media, with 1 copy offsite.

| Copy | Media/Location | Rotation |
|------|----------------|----------|
| **Primary** | `E:` (secondary drive, this server) | Daily |
| **Secondary** | `E:` (second local disk, e.g., NAS/desktop spare) | Daily |
| **Offsite** | Remote store (another server, NAS, or cloud object store) | Daily mirror + weekly archive |

**Important:** the secondary drive **E:** is still local to this server. Per the 3-2-1 rule, the **offsite copy is mandatory** — otherwise a fire/theft of the building loses everything.

### 12.1 Offsite copy commands

**Option A — robocopy mirror to a remote UNC path (if the remote server is reachable on the LAN):**

```cmd
robocopy E:\Backups\ \\REMOTE\Share\Backup\WINTHIRTYSIX /MIR /XJ /R:2 /W:5 /LOG+:\\REMOTE\Share\Backup\logs\offsite-robocopy.log
```

**Option B — Bits transfer to a cloud object store** (for truly offsite, e.g., Azure Blob/AWS S3/SMB via a branch office):

```powershell
# Upload a single nightly archive (example: the latest Hyper-V export)
$src = 'E:\Backups\HyperV'
$dest = 'https://mystorage.blob.core.windows.net/backup/winthirtysix'
Start-BitsTransfer -Source $src\Alpine1 -Destination $dest -ErrorAction Stop
```

**Option C — Azure CLI upload** (best for production:

```bash
az storage blob upload-batch -s "E:\Backups" -d "backup/winthirtysix" --account-name mystorage --account-key "<key>" --overwrite true
```

### 12.2 Offsite verification

After the offsite mirror, verify the remote copy exists and is non-empty:

```cmd
dir \\REMOTE\Share\Backup\WINTHIRTYSIX /s /a
```

Expected: all four job folders present (`AD\`, `Files\`, `GPO\`, `HyperV\`) with files inside.

### 12.3 Offsite retention

- Keep the offsite copy for at least **as long as the local copy** (§8).
- If using cloud, enable **versioning** and **soft-delete** so a bad upload is reversible.
- Once a quarter, test pulling a file from the offsite store back to the local server to confirm the offsite path is truly readable.

---

## 13. Reference Script Files (place under `C:\Backup\`)

| File | Purpose |
|------|---------|
| `C:\Backup\FileBackup.ps1` | Robocopy incremental file backup |
| `C:\Backup\GPOBackup.ps1` | Backup-GPO -All + HTML reports |
| `C:\Backup\HyperVExport.ps1` | Export all 8 VMs to E: |
| `C:\Backup\Cleanup-Retention.ps1` | Monthly cleanup of old versions |
| `C:\Backup\RestoreTests.ps1` | Weekly test-restore harness + log |

Each script must run in an **elevated** PowerShell session.

---

## 14. Summary of Exact Commands

```cmd
:: ---- AD System State (daily) ----
wbadmin start backup -BackupTarget:E: -IncludeSystemState -Version:1.0 -BackupId:AD-SystemState-Daily -Description:"AD system state daily" -AllowReboot

:: ---- Verify backups ----
wbadmin get versions -target:backup -quiet
wbadmin get items -backupTarget:E: -ItemType:backup

:: ---- Restore system state ----
wbadmin start restore -BackupTarget:E: -Version:1.0 -ItemType:SYSTEMSTATE -RestoreTarget:C: -Confirm

:: ---- Files (Robocopy incremental) ----
robocopy C:\Shares E:\Backups\Files\20261009 /MIR /XJ /R:2 /W:5 /NP /V /LOG+:E:\Backups\Logs\Shares-20261009.log

:: ---- Files (wbadmin directory capture, weekly) ----
wbadmin start backup -BackupTarget:E: -CaptureFile:E:\Backup\CaptureFiles\fileBackup.xml -Include:C:\Shares,C:\Software,C:\Hyper-V,C:\GPOBackup,C:\Temp,C:\inetpub -Version:1.0 -BackupId:FileBackup-Weekly -Description:"Weekly file backup" -AllowReboot

:: ---- GPOs ----
Backup-GPO -All -Path "E:\Backups\GPO\20261009"
Get-GPO -All | ForEach-Object { Get-GPOReport -Name $_.DisplayName -Path "E:\Backups\GPO\$($_.DisplayName).html" -ReportType Html }

:: ---- Hyper-V export ----
Export-VM -Name "Alpine1","Alpine2","Alpine3","Alpine4","Manager1","node1","node2","node3" -Path "E:\Backups\HyperV\" -Verify -Force

:: ---- Hyper-V restore ----
Import-VM -Path "E:\Backups\HyperV\Alpine1" -GenerateNewID

:: ---- Verify ----
Get-GPO -All | Select-Object DisplayName, Id, CreationTime
Get-VM | Select-Object Name, State, MemoryStartup
netdom query fsmo
wbadmin get versions -target:backup -quiet

:: ---- Offsite (mirror to remote) ----
robocopy E:\Backups\ \\REMOTE\Share\Backup\WINTHIRTYSIX /MIR /XJ /R:2 /W:5 /LOG+:E:\Backups\Logs\offsite-robocopy.log
```

---

*Plan generated 2026-10-09 for WINTHIRTYSIX (lab.local). Backup destination = E: (secondary drive, NTFS, 42.48 GB free).*
