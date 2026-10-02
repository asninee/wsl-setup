# wsl-setup

Quick, re-runnable WSL (Debian/Ubuntu) bootstrap.

| Layer | Tool | Where |
|---|---|---|
| System essentials | apt | `setup.sh` (`step_apt`) |
| User-local CLI tools | Homebrew | `Brewfile` |
| Language versions | mise | `config/mise.toml` |
| Shell activation | bash / fish | `shell/env.{bash,fish}` |

## Fresh machine

```bash
sudo apt-get update && sudo apt-get install -y git
git clone <this-repo> ~/dev/wsl-setup
~/dev/wsl-setup/setup.sh
```

## Day to day

```bash
./setup.sh                 # everything (safe to re-run)
./setup.sh bundle mise     # only selected steps
```

Steps: `apt wsl brew bundle link mise shell`

- Add a CLI tool: add it to `Brewfile`, run `./setup.sh bundle` (or `brew install x && brew bundle dump --force --file Brewfile`).
- Add/change a language: `mise use -g go@latest` (writes to `config/mise.toml` via symlink), commit.
- Per-project versions: `mise use node@22` inside the project.
