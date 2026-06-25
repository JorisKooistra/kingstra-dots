# =============================================================================
# 00-init.zsh — Basisomgeving, paden, geschiedenis
# =============================================================================

# XDG-standaarden
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# XDG-naleving: voorkom rommel in $HOME
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
export DOTNET_CLI_HOME="$XDG_DATA_HOME/dotnet"
export NUGET_PACKAGES="$XDG_DATA_HOME/nuget"
export ELECTRON_GYP_USERHOME="$XDG_CACHE_HOME/electron-gyp"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export NPM_CONFIG_PREFIX="$XDG_DATA_HOME/npm"

# Standaard editor
export EDITOR="nvim"
export VISUAL="$EDITOR"

# PATH aanvullen
path=(
    "$HOME/.local/bin"
    "$CARGO_HOME/bin"
    "$NPM_CONFIG_PREFIX/bin"
    /usr/local/bin
    $path
)
export PATH

# Geschiedenis
HISTFILE="${XDG_STATE_HOME}/zsh/history"
HISTSIZE=50000
SAVEHIST=50000

mkdir -p "$(dirname "$HISTFILE")"

setopt HIST_IGNORE_ALL_DUPS   # Verwijder duplicaten uit geschiedenis
setopt HIST_IGNORE_SPACE      # Regels met spatie vooraan niet opslaan
setopt SHARE_HISTORY          # Deel geschiedenis tussen sessies
setopt HIST_REDUCE_BLANKS     # Onnodige witruimte verwijderen
setopt EXTENDED_HISTORY       # Tijdstempel opslaan

# Completion
autoload -Uz compinit
compinit -d "${XDG_CACHE_HOME}/zsh/zcompdump-${ZSH_VERSION}"
mkdir -p "${XDG_CACHE_HOME}/zsh"

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # Case-insensitief
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Toetsenbordondersteuning
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search    # Pijl omhoog
bindkey "^[[B" down-line-or-beginning-search  # Pijl omlaag
bindkey "^[[H" beginning-of-line              # Home
bindkey "^[[F" end-of-line                    # End
bindkey "^[[3~" delete-char                   # Delete
bindkey "^H" backward-delete-word             # Ctrl+Backspace
bindkey "^[[1;5C" forward-word                # Ctrl+Rechts
bindkey "^[[1;5D" backward-word               # Ctrl+Links
