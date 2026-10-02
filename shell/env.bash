# Sourced from ~/.profile (login, non-interactive: shims) and ~/.bashrc (interactive: full activation).
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
fi

# Lets gpg ask for the signing-key passphrase in this terminal.
case $- in *i*) export GPG_TTY="$(tty)" ;; esac

[ -n "${BROWSER:-}" ] || export BROWSER="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../bin/wsl-open"

if command -v mise >/dev/null 2>&1; then
  case $- in
    *i*) eval "$(mise activate bash)" ;;
    *) eval "$(mise activate bash --shims)" ;;
  esac
fi
