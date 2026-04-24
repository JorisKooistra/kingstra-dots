# =============================================================================
# 40-autostart.zsh — Autostart bij interactieve login-shells
# =============================================================================
# Alleen uitvoeren in interactieve shells, niet in scripts.

[[ -o interactive ]] || return

_kingstra_clear_terminal_for_fetch() {
    [[ -t 1 ]] || return 0
    # Clear viewport and scrollback so installer/update output cannot sit behind fastfetch.
    printf '\033[H\033[2J\033[3J'
}

# fastfetch tonen bij nieuwe terminalsessie
if command -v fastfetch &>/dev/null; then
    _kingstra_clear_terminal_for_fetch
    fastfetch
fi
