# =============================================================================
# ~/.config/zsh/.zshrc — kingstra-dots
# =============================================================================
# Laadt alle conf.d-modules in volgorde.
# Voeg je eigen aanpassingen toe in conf.d/90-custom.zsh.
# =============================================================================

KINGSTRA_ZSH_DIR="${ZDOTDIR:-$HOME/.config/zsh}"

# Alle conf.d-bestanden inladen op alfabetische volgorde
if [[ -d "$KINGSTRA_ZSH_DIR/conf.d" ]]; then
    for _conf in "$KINGSTRA_ZSH_DIR/conf.d"/*.zsh(N); do
        source "$_conf"
    done
    unset _conf
fi
