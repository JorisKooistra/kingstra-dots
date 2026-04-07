# =============================================================================
# 30-prompt.zsh — oh-my-posh prompt
# =============================================================================

if command -v oh-my-posh &>/dev/null; then
    OMP_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/kingstra.omp.toml"

    if [[ -f "$OMP_THEME" ]]; then
        eval "$(oh-my-posh init zsh --config "$OMP_THEME")"
    else
        # Fallback naar ingebouwd thema als het bestand er niet is
        eval "$(oh-my-posh init zsh --config "$(oh-my-posh get shell-path)/themes/catppuccin_mocha.omp.json" 2>/dev/null)" || \
        eval "$(oh-my-posh init zsh)"
    fi
fi
