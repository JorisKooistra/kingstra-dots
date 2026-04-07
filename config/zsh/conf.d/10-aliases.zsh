# =============================================================================
# 10-aliases.zsh — Aliassen
# =============================================================================

# --- ls vervangen door eza ---
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lah --icons --group-directories-first --git'
    alias la='eza -a --icons --group-directories-first'
    alias lt='eza --tree --icons --level=2'
    alias llt='eza --tree --icons --level=3 -lah'
else
    alias ls='ls --color=auto'
    alias ll='ls -lahF --color=auto'
fi

# --- cat vervangen door bat ---
if command -v bat &>/dev/null; then
    alias cat='bat --style=plain'
    alias cath='bat'          # Volledig bat met headers/syntax
fi

# --- grep met kleur ---
alias grep='grep --color=auto'

# --- Navigatie ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# --- Systeem ---
alias q='exit'
alias clr='clear'
alias reload='exec zsh'       # Shell herladen
alias path='echo $PATH | tr ":" "\n"'

# --- Pakketbeheer (Arch) ---
alias pacs='sudo pacman -S'
alias pacr='sudo pacman -Rns'
alias pacu='sudo pacman -Syu'
alias pacss='pacman -Ss'
alias pacq='pacman -Qi'

if command -v yay &>/dev/null; then
    alias yays='yay -S'
    alias yayu='yay -Syu'
elif command -v paru &>/dev/null; then
    alias yays='paru -S'
    alias yayu='paru -Syu'
fi

# --- Hyprland helpers ---
alias hyprreload='hyprctl reload'
alias hyprlog='journalctl --user -u hyprland -f'

# --- Git ---
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'

# --- Diversen ---
alias df='df -h'
alias du='du -sh *'
alias free='free -h'
alias ip='ip -c'
