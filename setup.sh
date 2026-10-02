#!/usr/bin/env bash
# Idempotent WSL bootstrap: apt essentials -> Homebrew -> brew bundle -> configs -> mise -> auth -> shell.
# Usage: ./setup.sh            # run every step
#        ./setup.sh brew mise  # run selected steps only
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREW_PREFIX=/home/linuxbrew/.linuxbrew
STEPS=(apt wsl brew bundle link mise auth shell)

log() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }

step_apt() {
  log "apt: system essentials"
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    build-essential procps curl file git ca-certificates gnupg unzip locales
}

step_wsl() {
  log "wsl: enable systemd"
  if ! grep -qs '^systemd=true' /etc/wsl.conf; then
    printf '[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf >/dev/null
    echo "Updated /etc/wsl.conf - run 'wsl --shutdown' from Windows to apply."
  fi
}

step_brew() {
  log "brew: install Homebrew"
  if [[ ! -x $BREW_PREFIX/bin/brew ]]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

step_bundle() {
  log "bundle: install Brewfile packages"
  brew bundle install --file "$ROOT/Brewfile"
}

link() {
  mkdir -p "$(dirname "$2")"
  ln -sfn "$1" "$2"
  echo "  $2 -> $1"
}

append_once() {
  grep -qsF "$2" "$1" || printf '\n%s\n' "$2" >>"$1"
}

step_link() {
  log "link: shell + mise config"
  link "$ROOT/config/mise.toml" "$HOME/.config/mise/config.toml"
  link "$ROOT/shell/env.fish" "$HOME/.config/fish/conf.d/00-env.fish"
  append_once "$HOME/.profile" ". \"$ROOT/shell/env.bash\""
  append_once "$HOME/.bashrc" ". \"$ROOT/shell/env.bash\""
}

step_mise() {
  log "mise: install language toolchains"
  mise install --yes
}

set_npmrc() {
  local file="$HOME/.npmrc" key="$1" value="$2"
  touch "$file"
  (umask 077 && { grep -vF "$key=" "$file" || true; } >"$file.tmp")
  printf '%s=%s\n' "$key" "$value" >>"$file.tmp"
  mv "$file.tmp" "$file"
  chmod 600 "$file"
}

step_auth() {
  log "auth: GitHub CLI, git identity, npm (GitHub Packages)"
  local host=github.com
  export BROWSER="${BROWSER:-$ROOT/bin/wsl-open}"
  # GH_TOKEN (optional, for unattended runs) is stored via `gh auth login`, then dropped so gh uses the stored login.
  local token=${GH_TOKEN:-}
  unset GH_TOKEN

  if ! gh auth status --hostname "$host" >/dev/null 2>&1; then
    if [[ -n $token ]]; then
      printf '%s\n' "$token" | gh auth login --hostname "$host" --git-protocol https --with-token
    elif [[ -t 0 ]]; then
      echo "  A browser will open: sign in to GitHub and enter the code shown below."
      gh auth login --hostname "$host" --git-protocol https --web --scopes read:packages
    else
      echo "  No terminal to log in from; skipping. Run './setup.sh auth' later."
      return
    fi
  fi

  if ! gh auth status --hostname "$host" 2>&1 | grep -q "read:packages"; then
    if [[ -t 0 ]]; then
      echo "  Adding the read:packages permission (needed for npm installs from GitHub Packages)."
      gh auth refresh --hostname "$host" --scopes read:packages
    else
      echo "  Warning: token lacks read:packages; run 'gh auth refresh -s read:packages' later."
    fi
  fi

  gh auth setup-git --hostname "$host"

  if [[ -z $(git config --global user.email || true) ]]; then
    local id login name
    IFS=$'\t' read -r id login name < <(gh api user --jq '[.id, .login, (.name // .login)] | @tsv')
    git config --global user.name "$name"
    git config --global user.email "$id+$login@users.noreply.github.com"
    echo "  git identity: $name <$id+$login@users.noreply.github.com>"
  fi
  git config --global init.defaultBranch main

  set_npmrc "//npm.pkg.github.com/:_authToken" "$(gh auth token --hostname "$host")"
  local scope
  while read -r scope; do
    [[ -z $scope || $scope == \#* ]] && continue
    scope=${scope,,}
    set_npmrc "$scope:registry" "https://npm.pkg.github.com"
    echo "  npm: $scope -> GitHub Packages"
  done <"$ROOT/config/npm-scopes"
}

step_shell() {
  log "shell: set default shell to brew fish"
  local fish="$BREW_PREFIX/bin/fish"
  [[ -x $fish ]] || { echo "  fish not installed, skipping"; return; }
  grep -qxF "$fish" /etc/shells || echo "$fish" | sudo tee -a /etc/shells >/dev/null
  if [[ $(getent passwd "$(id -un)" | cut -d: -f7) != "$fish" ]]; then
    sudo chsh -s "$fish" "$(id -un)"
  fi
}

main() {
  [[ $EUID -ne 0 ]] || { echo "Run as your normal user, not root." >&2; exit 1; }
  local steps=("$@")
  [[ ${#steps[@]} -gt 0 ]] || steps=("${STEPS[@]}")
  for s in "${steps[@]}"; do
    declare -F "step_$s" >/dev/null || { echo "Unknown step '$s'. Valid: ${STEPS[*]}" >&2; exit 1; }
  done
  for s in "${steps[@]}"; do
    [[ -x $BREW_PREFIX/bin/brew ]] && eval "$("$BREW_PREFIX/bin/brew" shellenv bash)"
    "step_$s"
  done
  log "Done. Open a new terminal to pick up changes."
}

main "$@"
