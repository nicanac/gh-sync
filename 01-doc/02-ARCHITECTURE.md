# 02 — Architecture

This document describes the software architecture of gh-sync using **C4 model** diagrams (Mermaid syntax).

---

## Level 1 — System Context

This diagram shows gh-sync in the context of the people and external systems it interacts with.

```mermaid
C4Context
  title System Context — gh-sync

  Person(dev, "Developer", "Manages AI configs across multiple projects")

  System(ghsync, "gh-sync CLI", "Cross-platform CLI tool that syncs AI config folders between a golden source and project directories")

  System_Ext(golden, "Golden Source Directory", "Single source of truth containing .github, .agent, .agents, .claude folders")
  System_Ext(projects, "Project Directories", "One or more software project directories that receive synced configs")
  System_Ext(filesystem, "Local Filesystem", "OS filesystem providing file I/O, hashing, and stat operations")

  Rel(dev, ghsync, "Runs commands", "CLI (push/pull/diff/status/backups/restore/clean/init)")
  Rel(ghsync, golden, "Reads/writes config files", "File I/O")
  Rel(ghsync, projects, "Reads/writes config files", "File I/O")
  Rel(ghsync, filesystem, "Uses", "find, stat, md5sum/shasum")
```

---

## Level 2 — Container Diagram

gh-sync is a **standalone** CLI application with two parallel implementations. There is no server, no database, and no network communication.

```mermaid
C4Container
  title Container Diagram — gh-sync

  Person(dev, "Developer", "Uses the CLI tool")

  Container_Boundary(ghsync, "gh-sync CLI Tool") {
    Container(bash, "gh-sync.sh", "Bash 4+", "Primary script for Linux, macOS, WSL, Git Bash. ~950 lines")
    Container(ps, "gh-sync.ps1", "PowerShell", "Windows-native implementation. ~579 lines")
    Container(cmd, "gh-sync.cmd", "Windows CMD", "Thin wrapper that delegates to gh-sync.ps1")
    Container(installBash, "install.sh", "Bash", "Installer for Unix/WSL: copies to ~/.local/bin, updates PATH")
    Container(installPs, "install.ps1", "PowerShell", "Installer for Windows: copies to ~/bin, updates user PATH")
    Container(installCmd, "install.cmd", "Windows CMD", "Thin wrapper that delegates to install.ps1")
  }

  System_Ext(configFile, "~/.gh-sync-config & .gh-sync.json", "Stores configuration locally and globally")
  System_Ext(golden, "Golden Source", "Directory with .github, .agent, .agents, .claude")
  System_Ext(project, "Project Directory", "Target directory for sync operations")
  System_Ext(backups, "$TMPDIR/gh-sync-backup-*", "Timestamped backups before each sync")

  Rel(dev, bash, "Executes", "Terminal")
  Rel(dev, cmd, "Executes", "Windows Terminal")
  Rel(cmd, ps, "Delegates to", "powershell.exe")
  Rel(bash, configFile, "Reads/writes", "File I/O")
  Rel(ps, configFile, "Reads/writes", "File I/O")
  Rel(bash, golden, "Reads/writes files", "find + cp")
  Rel(bash, project, "Reads/writes files", "find + cp")
  Rel(ps, golden, "Reads/writes files", "Get-ChildItem + Copy-Item")
  Rel(ps, project, "Reads/writes files", "Get-ChildItem + Copy-Item")
  Rel(bash, backups, "Creates before sync", "cp -a")
  Rel(ps, backups, "Creates before sync", "Copy-Item")
```

---

## Level 3 — Component Diagram (Bash Implementation)

This breaks down the internal structure of `gh-sync.sh` — the most complex artifact in the project.

```mermaid
C4Component
  title Component Diagram — gh-sync.sh Internal Structure

  Container_Boundary(bash_script, "gh-sync.sh") {
    Component(argParser, "Argument Parser", "Bash", "Parses CLI args: action, path, flags (--dry-run, --force, --exclude, --only, etc.)")
    Component(goldenResolver, "Golden Source Resolver", "Bash", "Resolves golden path from $GH_SYNC_SOURCE env var or ~/.gh-sync-config")
    Component(fileCollector, "File Collector (get_all_files)", "Bash + awk", "Batched find + hash + stat, outputs TSV with rel_path, full_path, mtime, size, hash")
    Component(comparator, "Folder Comparator (compare_folders)", "Bash + comm + join", "Diff two directories: ONLY_IN_SOURCE, ONLY_IN_TARGET, MODIFIED")
    Component(syncer, "Folder Syncer (sync_folder)", "Bash", "Copies changed files, creates backups, reports per-folder results")
    Component(actions, "Action Dispatchers", "Bash", "do_push, do_pull, do_diff, do_status, do_init, do_backups, do_restore, do_clean")
    Component(logging, "Logging Helpers", "Bash", "Color-coded output: write_ok, write_err, write_warn, write_info, write_header")
    Component(cleanup, "Cleanup & Error Traps", "Bash", "Temp dir registry, EXIT trap, ERR trap for safe resource cleanup")
    Component(excluder, "Exclusion Filter (should_exclude)", "Bash", "Glob-pattern matching against relative paths")
    Component(pathNorm, "Path Normalizer", "Bash", "Converts Windows backslashes to forward slashes for MINGW64 compatibility")
  }

  Rel(argParser, actions, "Dispatches action")
  Rel(actions, goldenResolver, "Gets golden source path")
  Rel(actions, comparator, "Computes diffs")
  Rel(actions, syncer, "Executes file copy")
  Rel(comparator, fileCollector, "Collects file metadata")
  Rel(fileCollector, excluder, "Filters excluded paths")
  Rel(fileCollector, pathNorm, "Normalizes paths")
  Rel(syncer, logging, "Reports progress")
  Rel(cleanup, logging, "Reports errors")
```

---

## Level 3 — Component Diagram (PowerShell Implementation)

```mermaid
C4Component
  title Component Diagram — gh-sync.ps1 Internal Structure

  Container_Boundary(ps_script, "gh-sync.ps1") {
    Component(params, "CmdletBinding Parameters", "PowerShell", "Action, ProjectPath, DryRun, Force, Exclude, Only, Keep, All, Latest")
    Component(goldenResolverPs, "Get-GoldenSource", "PowerShell", "Resolves from $env:GH_SYNC_SOURCE or ~/.gh-sync-config")
    Component(fileCollectorPs, "Get-AllFiles", "PowerShell", "Get-ChildItem + Get-FileHash (MD5) → PSCustomObject array")
    Component(comparatorPs, "Compare-Folders", "PowerShell", "Builds source/target hash maps, computes ONLY_IN_SOURCE, ONLY_IN_TARGET, MODIFIED")
    Component(syncerPs, "Invoke-SyncFolder", "PowerShell", "Copies changed files, creates backups, returns copy count")
    Component(initPs, "Init Block", "PowerShell", "Reads user input for golden path, saves to config file")
    Component(actionBlocks, "Action Blocks (if/elseif)", "PowerShell", "push, pull, diff, status, backups, restore, clean")
    Component(loggingPs, "Logging Functions", "PowerShell", "Write-Header, Write-Ok, Write-Warn, Write-Err, Write-Info")
  }

  Rel(params, actionBlocks, "Routes action")
  Rel(actionBlocks, goldenResolverPs, "Gets golden source")
  Rel(actionBlocks, comparatorPs, "Computes diffs")
  Rel(actionBlocks, syncerPs, "Syncs files")
  Rel(comparatorPs, fileCollectorPs, "Gets file metadata")
  Rel(syncerPs, loggingPs, "Reports results")
```

---

## Dynamic Diagram — Push Flow

This shows the step-by-step sequence when a user runs `gh-sync push`.

```mermaid
C4Dynamic
  title Dynamic Diagram — Push Flow

  Person(dev, "Developer", "Runs gh-sync push")

  Container_Boundary(ghsync, "gh-sync") {
    Component(parser, "Argument Parser", "Bash/PS", "Parse CLI args")
    Component(resolver, "Golden Resolver", "Bash/PS", "Get golden path")
    Component(comparator, "Comparator", "Bash/PS", "Diff folders")
    Component(syncer, "Syncer", "Bash/PS", "Copy files")
  }

  System_Ext(config, "~/.gh-sync-config", "Config file")
  System_Ext(golden, "Golden Source", "Source files")
  System_Ext(project, "Project Dir", "Target files")
  System_Ext(backup, "$TMPDIR backup", "Backup dir")

  Rel(dev, parser, "1. gh-sync push", "CLI")
  Rel(parser, resolver, "2. Resolve golden path")
  Rel(resolver, config, "3. Read config", "File I/O")
  Rel(parser, comparator, "4. Compare each folder")
  Rel(comparator, golden, "5. Scan files + hash", "find/stat/md5")
  Rel(comparator, project, "6. Scan files + hash", "find/stat/md5")
  Rel(parser, syncer, "7. If confirmed, sync")
  Rel(syncer, project, "8. Backup target to $TMPDIR", "cp -a")
  Rel(syncer, project, "9. Copy changed files", "cp")
```

---

## Deployment Diagram

gh-sync is a purely local tool — no servers, no cloud, no containers.

```mermaid
C4Deployment
  title Deployment Diagram — gh-sync

  Deployment_Node(unix, "Linux / macOS / WSL Machine", "Developer workstation") {
    Deployment_Node(binDir, "~/.local/bin/", "On PATH") {
      Container(bashBin, "gh-sync", "Bash", "Installed copy of gh-sync.sh")
    }
    Deployment_Node(homeDir, "$HOME", "User home") {
      Container(configUnix, ".gh-sync-config", "Text", "Stores golden source path")
    }
  }

  Deployment_Node(windows, "Windows Machine", "Developer workstation") {
    Deployment_Node(winBin, "~/bin/", "On user PATH") {
      Container(psBin, "gh-sync.ps1", "PowerShell", "Main Windows script")
      Container(cmdBin, "gh-sync.cmd", "CMD", "Wrapper for PowerShell")
    }
    Deployment_Node(winHome, "%USERPROFILE%", "User home") {
      Container(configWin, ".gh-sync-config", "Text", "Stores golden source path")
    }
  }
```

---

## Data Flow Summary

```
1. User runs: gh-sync <action> [path] [flags]

2. Argument parsing
   → Validate action (push|pull|diff|status|init|backups|restore|clean)
   → Extract --dry-run, --force, --exclude, --only, --keep, --all, --latest

3. Configuration & Golden source resolution
   → Check $GH_SYNC_SOURCE env var
   → Check local .gh-sync.json in project
   → Fallback: read ~/.gh-sync-config

4. For each sync folder (.github, .agent, .agents, .claude):
   a. Collect all files in source dir
      → find + batch md5sum/shasum + batch stat
      → Merge into TSV: rel_path | full_path | mtime | size | hash
      → Apply exclusion filters
   b. Collect all files in target dir (same process)
   c. Compare using sorted key diff:
      → comm -23: files only in source
      → comm -13: files only in target
      → join + hash compare: modified files

5. Display results (diff/status) or execute sync (push/pull):
   a. If --dry-run → show what would change, exit
   b. If not --force → prompt "Proceed? [y/N]"
   c. Create timestamped backup of target folder
   d. Copy changed files (ONLY_IN_SOURCE + MODIFIED)
   e. Report per-folder and grand-total stats
```
