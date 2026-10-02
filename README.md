# wsl-setup

One command to get a ready-to-code Linux environment on Windows (WSL + Debian or Ubuntu + Homebrew + mise).

## Install (Windows)

1. Press **Start**, type **PowerShell**, open it.
2. Paste this and press **Enter**:

   ```powershell
   irm https://raw.githubusercontent.com/asninee/wsl-setup/main/install.ps1 | iex
   ```

3. Pick **Debian** (default) or **Ubuntu** (latest LTS), then choose a Linux username and password when asked (the password is what `sudo` asks for later).
4. When asked, sign in to GitHub in the browser window that opens and enter the code shown in the terminal.
5. Wait a few minutes. When it says **All done!**, open your distro (**Debian** or **Ubuntu**) from the Start menu or Windows Terminal.

If WSL wasn't installed yet, it will ask you to **restart your PC**. After you sign back in, setup continues on its own.

> Prefer not to paste commands? Download this repo as a ZIP (green **Code** button → **Download ZIP**), extract it and double-click `install.cmd`.

Options (custom distro name / username):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/asninee/wsl-setup/main/install.ps1))) -Distro Ubuntu -Name dev -UserName me
```

Use `-UseImport` to skip `wsl --install` and import the official distro image directly.

### Requirements / work devices

- **WSL 2 only.** It needs virtualization enabled (BIOS/UEFI) and the *Virtual Machine Platform* Windows feature. On a managed device, ask IT if setup says WSL 2 is unavailable.
- **No admin rights needed** when WSL is already installed (distros are per-user). Only installing WSL itself needs admin; standard users are told to ask IT instead of getting a UAC prompt.
- Never runs `wsl --update` and doesn't need the Microsoft Store. On WSL older than 2.4.4, or if `wsl --install` is blocked, it downloads the official distro image (checksum-verified) and uses `wsl --import`.

Re-running is safe: an existing distro/user is reused and setup only installs what's missing.

## What you get

| Layer | Tool | Where |
|---|---|---|
| System essentials | apt | `setup.sh` (`step_apt`) |
| User-local CLI tools | Homebrew | `Brewfile` |
| Language versions | mise | `config/mise.toml` |
| Shell (fish default) | bash / fish | `shell/env.{bash,fish}` |
| GitHub + npm auth | gh | `config/npm-scopes` |

## Day to day (inside WSL)

The repo is cloned to `~/dev/wsl-setup`.

```bash
cd ~/dev/wsl-setup
./setup.sh                 # everything (safe to re-run)
./setup.sh bundle mise     # only selected steps
```

Steps: `apt wsl brew bundle link mise auth sign shell`

- Add a CLI tool: add it to `Brewfile`, run `./setup.sh bundle`.
- Add/change a language: `mise use -g go@latest` (writes to `config/mise.toml` via symlink), commit.
- GitHub / npm login: `./setup.sh auth` (re-run any time). It logs in `gh` (with `read:packages`), makes gh the git credential helper, sets your git name/email from GitHub (noreply address) if unset, and writes the GitHub Packages token to `~/.npmrc`. Scopes in `config/npm-scopes` (e.g. `@tswdts`) are routed to GitHub Packages.
- Commit signing: `./setup.sh sign` creates an ed25519 GPG key for your git email (you choose a passphrase), uploads it to GitHub (asks for the `write:gpg_key` permission) and turns on signing for all commits/tags. The passphrase is asked on first commit and cached for 8 hours. If an editor (e.g. VS Code) can't commit, make one commit in the terminal first to unlock the key.
- Per-project versions: `mise use node@22` inside the project.
