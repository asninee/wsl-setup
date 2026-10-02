if test -x /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv fish | source
end

# Brew's mise ships vendor_conf.d auto-activation; disable it so activation happens once, here.
set -gx MISE_FISH_AUTO_ACTIVATE 0
if type -q mise
    if status is-interactive
        mise activate fish | source
    else
        mise activate fish --shims | source
    end
end
