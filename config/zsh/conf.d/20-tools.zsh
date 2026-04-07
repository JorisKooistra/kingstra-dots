# =============================================================================
# 20-tools.zsh — Tool-integraties (fzf, yazi, zsh-plugins)
# =============================================================================

# --- fzf ---
if command -v fzf &>/dev/null; then
    source <(fzf --zsh) 2>/dev/null || true

    export FZF_DEFAULT_OPTS="
        --height 40%
        --layout=reverse
        --border=rounded
        --info=inline
        --prompt='  '
        --pointer='▶'
        --marker='✓'
        --color=bg+:#1e1e2e,bg:#181825,spinner:#f5c2e7,hl:#f38ba8
        --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5c2e7
        --color=marker:#f5c2e7,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
    "

    if command -v fd &>/dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    fi

    # Ctrl+R — betere geschiedenis-zoeker
    bindkey '^R' fzf-history-widget
fi

# --- Yazi — shell wrapper zodat cd werkt na afsluiten ---
if command -v yazi &>/dev/null; then
    function y() {
        local tmp
        tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if [[ -f "$tmp" ]]; then
            local cwd
            cwd="$(cat "$tmp")"
            if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
                cd "$cwd" || return
            fi
            rm -f "$tmp"
        fi
    }
fi

# --- zsh-autosuggestions ---
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#585b70'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# --- zsh-syntax-highlighting (moet als laatste geladen worden) ---
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
