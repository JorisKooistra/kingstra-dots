# =============================================================================
# 40-autostart.zsh — Autostart bij interactieve login-shells
# =============================================================================
# Alleen uitvoeren in interactieve shells, niet in scripts.

[[ -o interactive ]] || return

# fastfetch tonen bij nieuwe terminalsessie
# Alleen als we niet al in een kitty-sessie zitten die al fetch heeft gedraaid
if command -v fastfetch &>/dev/null; then
    fastfetch
fi
