# Sourced from ~/.profile (login, non-interactive: shims) and ~/.bashrc (interactive: full activation).
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
fi

if command -v mise >/dev/null 2>&1; then
  case $- in
    *i*) eval "$(mise activate bash)" ;;
    *) eval "$(mise activate bash --shims)" ;;
  esac
fi
