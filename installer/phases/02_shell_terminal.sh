#!/usr/bin/env bash
# =============================================================================
# Fase 02 — Shell en terminalbasis
# =============================================================================
# Doel:
#   - zsh installeren en als standaard shell instellen
#   - oh-my-posh installeren
#   - zsh-plugins installeren (autosuggestions, syntax-highlighting)
#   - ZDOTDIR instellen via ~/.zshenv
#   - kitty installeren en configureren
#   - fastfetch installeren en configureren
#   - cava installeren en configureren
#   - btop installeren
# =============================================================================

phase_run() {
    log_step "Pakketten installeren voor shell en terminal..."
    _phase02_install_packages

    log_step "zsh als standaard shell instellen..."
    _phase02_set_default_shell

    log_step "ZDOTDIR instellen..."
    _phase02_set_zdotdir

    log_step "Configs deployen..."
    _phase02_deploy_configs

    log_step "Kitty runtime-bestanden initialiseren..."
    _phase02_init_kitty_runtime_files

    log_step "Fase 02 valideren..."
    _phase02_validate

    log_ok "Fase 02 voltooid — shell en terminal klaar."
}

# ---------------------------------------------------------------------------

_phase02_install_packages() {
    # Shell
    pacman_install zsh zsh-autosuggestions zsh-syntax-highlighting
    aur_install oh-my-posh-bin

    # Terminal
    pacman_install kitty

    # Systeeminfo + audio visualizer + monitor
    pacman_install fastfetch cava btop

    # Handige CLI-tools (gebruikt in aliases en zsh integraties)
    pacman_install eza bat fd ripgrep fzf jq yazi
}

_phase02_set_default_shell() {
    local zsh_path
    zsh_path="$(command -v zsh 2>/dev/null || echo "")"

    if [[ -z "$zsh_path" ]]; then
        log_warn "zsh niet gevonden — standaard shell niet gewijzigd."
        return 0
    fi

    if [[ "$SHELL" == "$zsh_path" ]]; then
        log_info "zsh is al de standaard shell."
        return 0
    fi

    # Voeg zsh toe aan /etc/shells als het er nog niet in staat
    if ! grep -qx "$zsh_path" /etc/shells; then
        log_step "zsh toevoegen aan /etc/shells..."
        run_cmd sudo tee -a /etc/shells <<< "$zsh_path"
    fi

    log_step "chsh -s $zsh_path"
    run_cmd chsh -s "$zsh_path"
    log_ok "Standaard shell ingesteld op: $zsh_path"
}

_phase02_set_zdotdir() {
    local zshenv="$HOME/.zshenv"
    local zdotdir_line='export ZDOTDIR="$HOME/.config/zsh"'

    if "${DRY_RUN:-false}"; then
        log_dry "~/.zshenv schrijven met ZDOTDIR"
        return 0
    fi

    # Voeg de regel toe als die er nog niet in staat
    if [[ -f "$zshenv" ]] && grep -q "ZDOTDIR" "$zshenv"; then
        log_info "ZDOTDIR al aanwezig in ~/.zshenv"
    else
        backup_path "$zshenv"
        echo "$zdotdir_line" >> "$zshenv"
        log_ok "ZDOTDIR toegevoegd aan ~/.zshenv"
    fi
}

_phase02_deploy_configs() {
    deploy_config "zsh"
    deploy_config "kitty"
    deploy_config "fastfetch"
    deploy_config "cava"
}

_phase02_init_kitty_runtime_files() {
    local kitty_dir="$HOME/.config/kitty"
    local runtime_conf="$kitty_dir/kitty-runtime.conf"
    local skwd_theme_conf="$kitty_dir/skwd-theme.generated.conf"
    local legacy_conf="$kitty_dir/kitty-matugen-colors.conf"

    if "${DRY_RUN:-false}"; then
        log_dry "Kitty runtime placeholders initialiseren in $kitty_dir"
        return 0
    fi

    ensure_dir "$kitty_dir"

    [[ -f "$runtime_conf" ]] || cat > "$runtime_conf" <<'EOF'
# Runtime overrides for kitty (auto-generated).
EOF

    [[ -f "$skwd_theme_conf" ]] || cat > "$skwd_theme_conf" <<'EOF'
# skwd-wall generated theme include for kitty.
EOF

    [[ -f "$legacy_conf" ]] || cat > "$legacy_conf" <<'EOF'
# Legacy matugen colors include for kitty compatibility.
EOF

    log_ok "Kitty runtime placeholders klaar"
}

_phase02_validate() {
    validate_cmd zsh
    validate_cmd kitty
    validate_cmd fastfetch
    validate_cmd cava
    validate_cmd btop
    validate_cmd oh-my-posh
    validate_file "$HOME/.config/zsh/.zshrc" "~/.config/zsh/.zshrc"
    validate_file "$HOME/.config/kitty/kitty.conf" "~/.config/kitty/kitty.conf"
    validate_file "$HOME/.config/fastfetch/config.jsonc" "~/.config/fastfetch/config.jsonc"
    validate_file "$HOME/.config/cava/config" "~/.config/cava/config"
    validate_report
}
