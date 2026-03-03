# 08 — Installation Guide

Step-by-step installation instructions for every supported platform.

---

## Platform Support Matrix

| Platform | Script Format | Shell | Installer |
|----------|---------------|-------|-----------|
| Linux | `gh-sync.sh` | Bash 4+ | `install.sh` |
| macOS | `gh-sync.sh` | Bash 4+ (via Homebrew) | `install.sh` |
| WSL | `gh-sync.sh` | Bash 4+ | `install.sh` |
| Git Bash (Windows) | `gh-sync.sh` | MINGW64 Bash | `install.sh` |
| Windows (native) | `gh-sync.ps1` + `gh-sync.cmd` | PowerShell 5.1+ | `install.ps1` or `install.cmd` |

---

## Linux / WSL Installation

### Prerequisites

- Bash 4.0 or higher (verifiable with `bash --version`)
- Standard utilities: `find`, `stat`, `md5sum` (or `shasum`), `awk`, `sort`, `comm`

> These are all included by default in virtually every Linux distribution.

### Option A: One-Liner Installer

```bash
git clone https://github.com/your-org/gh-sync.git
cd gh-sync
bash install.sh
```

**What this does:**
1. Creates `~/.local/bin/` if it doesn't exist (XDG standard)
2. Copies `gh-sync.sh` → `~/.local/bin/gh-sync` with execute permissions
3. Adds `~/.local/bin` to your `PATH` in the appropriate RC file (`~/.bashrc`, `~/.zshrc`, `~/.bash_profile`, or `~/.config/fish/config.fish`)
4. Shows next-step instructions

**After installation:**
```bash
# Open a new terminal (or source your RC file)
source ~/.bashrc

# Configure golden source
gh-sync init
```

### Option B: Manual Installation

```bash
# Copy the script
cp gh-sync.sh ~/.local/bin/gh-sync
chmod +x ~/.local/bin/gh-sync

# Ensure ~/.local/bin is on your PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Configure
gh-sync init
```

---

## macOS Installation

### Prerequisites

macOS ships with Bash 3.2, which is **too old**. You must install Bash 4+:

```bash
brew install bash
```

After installing, verify:
```bash
/opt/homebrew/bin/bash --version
# GNU bash, version 5.x.x ...
```

> **Note:** The default `/bin/bash` on macOS is still 3.2. The installer and gh-sync will use the first `bash` on your `$PATH`, which should be the Homebrew version.

### Installation

```bash
git clone https://github.com/your-org/gh-sync.git
cd gh-sync
bash install.sh
```

On macOS, the installer:
- Prefers `~/.local/bin` (creates it if needed)
- Detects your shell (zsh is default on modern macOS) and updates `~/.zshrc`
- Uses `md5` (BSD) or `shasum` for hashing since `md5sum` is not available by default

---

## Windows Installation (Native PowerShell)

### Prerequisites

- PowerShell 5.1+ (included in Windows 10/11)
- No additional dependencies

### Option A: Double-Click Installer

1. Download/clone the repository
2. Navigate to the `gh-sync` folder
3. Double-click **`install.cmd`**

This will:
1. Create `%USERPROFILE%\bin\` (e.g., `C:\Users\YourName\bin\`)
2. Copy `gh-sync.ps1` and `gh-sync.cmd` to `~/bin/`
3. Add `~/bin` to the user-level `PATH` environment variable
4. Pause so you can read the output

### Option B: PowerShell Installer

```powershell
cd path\to\gh-sync
.\install.ps1
```

### Option C: Manual Installation

```powershell
# Create bin directory
mkdir "$env:USERPROFILE\bin" -Force

# Copy files
copy gh-sync.ps1 "$env:USERPROFILE\bin\"
copy gh-sync.cmd "$env:USERPROFILE\bin\"

# Add to PATH (persists across sessions)
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$userPath;$env:USERPROFILE\bin", "User")
```

### After Installation

Open a **new terminal** (required for PATH changes to take effect):

```powershell
# If using PowerShell directly:
gh-sync.ps1 init

# If using CMD or the wrapper:
gh-sync init
```

---

## Windows Installation (Git Bash)

If you use Git Bash (MINGW64) on Windows, you can use the Bash version:

```bash
# From Git Bash terminal
bash install.sh
```

This installs `gh-sync` to `~/.local/bin/gh-sync` within the MINGW64 environment.

> **Note:** Git Bash typically includes `md5sum` via the coreutils package. The script handles `MINGW64` binary-mode markers (`*` prefix in md5sum output) automatically.

---

## First-Time Configuration

After installation (any platform):

```bash
gh-sync init
```

You will be prompted:

```
=== INIT: Configure gh-sync ===

  The golden source is a DIRECTORY containing your shared folders:
    .github/  .agent/  .agents/  .claude/

  Enter the path to your golden source directory: ~/my-golden-configs
```

After entering the path, gh-sync shows inventory:

```
  [OK] .github (19 files)
  [OK] .agents (70 files)
  [!!] .agent (not found -- will be skipped during sync)
  [!!] .claude (not found -- will be skipped during sync)

  [OK] Saved config to: /home/user/.gh-sync-config
  [OK] Golden source set to: /home/user/my-golden-configs

  ->  You can now use: gh-sync push, pull, diff, status
```

---

## Verification

Verify the installation works:

```bash
# Check version
gh-sync --version
# gh-sync 1.0.0

# Check help
gh-sync --help

# Check status (from any project directory)
cd ~/projects/my-app
gh-sync status
```

---

## Uninstallation

### Linux / macOS / WSL

```bash
rm -f ~/.local/bin/gh-sync    # or ~/bin/gh-sync
rm -f ~/.gh-sync-config
```

Optionally remove the PATH line from your shell RC file.

### Windows

```powershell
Remove-Item "$env:USERPROFILE\bin\gh-sync.ps1" -Force
Remove-Item "$env:USERPROFILE\bin\gh-sync.cmd" -Force
Remove-Item "$env:USERPROFILE\.gh-sync-config" -Force

# Optionally remove ~/bin from PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$cleanPath = ($userPath -split ';' | Where-Object { $_ -ne "$env:USERPROFILE\bin" }) -join ';'
[Environment]::SetEnvironmentVariable("Path", $cleanPath, "User")
```

---

## Troubleshooting

### "No hash command found"

Install one of: `md5sum`, `md5`, or `shasum`:
```bash
# Debian/Ubuntu
sudo apt install coreutils

# macOS (shasum is included, but md5sum can be added)
brew install coreutils
```

### "Golden source not configured"

Run `gh-sync init` or set the environment variable:
```bash
export GH_SYNC_SOURCE=/path/to/golden/source
```

### PowerShell Execution Policy Error

If you get "running scripts is disabled":
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Or use the CMD wrapper (`gh-sync.cmd`) which bypasses the policy automatically.

### "command not found: gh-sync"

Your `PATH` doesn't include the installation directory:
```bash
# Bash: open a new terminal, or:
source ~/.bashrc
# or
export PATH="$HOME/.local/bin:$PATH"
```

```powershell
# PowerShell: open a new terminal for PATH changes to apply
```
