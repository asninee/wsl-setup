# wsl-setup

One command to get a ready-to-code Linux environment on Windows (WSL + Debian + Homebrew + mise).

## Install (Windows)

1. Press **Start**, type **PowerShell**, open it.
2. Paste this and press **Enter**:

   ```powershell
   irm https://raw.githubusercontent.com/asninee/wsl-setup/main/install.ps1 | iex
   ```

3. Choose a Linux username and password when asked (the password is what `sudo` asks for later).
4. Wait a few minutes. When it says **All done!**, open **Debian** from the Start menu or Windows Terminal.

If WSL wasn't installed yet, it will ask you to **restart your PC**. After you sign back in, setup continues on its own.

> Prefer not to paste commands? Download this repo as a ZIP (green **Code** button → **Download ZIP**), extract it and double-click `install.cmd`.

Options (custom distro name / username):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/asninee/wsl-setup/main/install.ps1))) -Name dev -UserName me
```

Use `-UseImport` to skip `wsl --install` and import the official Debian image directly.

### Requirements / work devices

- **WSL 2 only.** It needs virtualization enabled (BIOS/UEFI) and the *Virtual Machine Platform* Windows feature. On a managed device, ask IT if setup says WSL 2 is unavailable.
- **No admin rights needed** when WSL is already installed (distros are per-user). Only installing WSL itself needs admin; standard users are told to ask IT instead of getting a UAC prompt.
- Never runs `wsl --update` and doesn't need the Microsoft Store. On WSL older than 2.4.4, or if `wsl --install` is blocked, it downloads the official Debian image (checksum-verified) and uses `wsl --import`.

Re-running is safe: an existing distro/user is reused and setup only installs what's missing.

## What you get

| Layer | Tool | Where |
|---|---|---|
| System essentials | apt | `setup.sh` (`step_apt`) |
| User-local CLI tools | Homebrew | `Brewfile` |
| Language versions | mise | `config/mise.toml` |
| Shell (fish default) | bash / fish | `shell/env.{bash,fish}` |

## Day to day (inside WSL)

The repo is cloned to `~/dev/wsl-setup`.

```bash
cd ~/dev/wsl-setup
./setup.sh                 # everything (safe to re-run)
./setup.sh bundle mise     # only selected steps
```

Steps: `apt wsl brew bundle link mise shell`

- Add a CLI tool: add it to `Brewfile`, run `./setup.sh bundle`.
- Add/change a language: `mise use -g go@latest` (writes to `config/mise.toml` via symlink), commit.
- Per-project versions: `mise use node@22` inside the project.
