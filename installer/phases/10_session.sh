#!/usr/bin/env bash
# =============================================================================
# Fase 10 — Sessielaag (hyprlock, hypridle, SDDM)
# =============================================================================
# Doel:
#   - hyprlock (lockscreen) installeren + config genereren via matugen
#   - hypridle installeren + config deployen
#   - SDDM installeren + activeren + config plaatsen
#   - Hyprlock matugen-template registreren in bestaande matugen config
# =============================================================================

phase_run() {
    log_step "Sessiepakketten installeren..."
    pacman_install hyprlock
    pacman_install hypridle
    pacman_install brightnessctl          # dimmen via hypridle listener

    log_step "SDDM installeren..."
    _phase10_install_sddm

    log_step "Hypridle-config deployen..."
    deploy_config "hypridle"

    log_step "Hyprlock-config genereren via matugen..."
    _phase10_generate_hyprlock

    log_step "SDDM-config plaatsen..."
    _phase10_deploy_sddm_config

    log_step "SDDM-service activeren..."
    _phase10_enable_sddm

    log_step "Fase 10 valideren..."
    validate_cmd hyprlock
    validate_cmd hypridle
    validate_file "$HOME/.config/hypridle/hypridle.conf" "hypridle.conf"
    validate_file "$HOME/.config/hyprlock/hyprlock.conf" "hyprlock.conf (matugen output)"
    validate_report

    log_ok "Fase 10 voltooid — Sessielaag actief."
    log_info "Vergrendelen:      Super+Ctrl+L (Quickshell Lock.qml)"
    log_info "Kleuren bijwerken: kingstra-theme-apply <wallpaper>  (werkt ook voor SDDM)"
}

# ---------------------------------------------------------------------------

_phase10_install_sddm() {
    pacman_install sddm

    if [[ "${ENABLE_SDDM:-true}" != "true" ]]; then
        return 0
    fi

    log_step "Kingstra SDDM-theme installeren..."
    _phase10_install_sddm_theme
}

_phase10_install_sddm_theme() {
    local theme_src="$REPO_ROOT/config/sddm/themes/kingstra"
    local theme_dest="/usr/share/sddm/themes/kingstra"

    if "${DRY_RUN:-false}"; then
        log_dry "SDDM-theme zou worden geïnstalleerd: $theme_dest"
        return 0
    fi

    sudo mkdir -p "$theme_dest"
    sudo cp -r "$theme_src/." "$theme_dest/"
    log_ok "SDDM-theme geïnstalleerd: $theme_dest"

    # Schrijfrechten geven voor matugen (Colors.qml wordt gegenereerd)
    sudo chmod 777 "$theme_dest"
    log_ok "Matugen kan Colors.qml schrijven naar $theme_dest"

    # Wallpaper uit kingstra state instellen als theme-achtergrond
    local state_file="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/last-wallpaper"
    if [[ -f "$state_file" ]]; then
        local wallpaper
        wallpaper="$(cat "$state_file")"
        if [[ -f "$wallpaper" ]]; then
            sudo sed -i "s|^background=.*|background=$wallpaper|" "$theme_dest/theme.conf"
            log_ok "SDDM-wallpaper ingesteld: $wallpaper"
        fi
    fi
}

_phase10_generate_hyprlock() {
    local hyprlock_dir="$HOME/.config/hyprlock"
    local hyprlock_conf="$hyprlock_dir/hyprlock.conf"

    if "${DRY_RUN:-false}"; then
        log_dry "Hyprlock-config zou worden gegenereerd via matugen → $hyprlock_conf"
        return 0
    fi

    ensure_dir "$hyprlock_dir"
    _phase10_ensure_hyprlock_matugen_template

    # Controleer of matugen beschikbaar is en al kleuren heeft gegenereerd
    if command -v kingstra-theme-apply &>/dev/null; then
        local state_file="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/last-wallpaper"
        if [[ -f "$state_file" ]] && [[ -f "$(cat "$state_file")" ]]; then
            log_step "Matugen uitvoeren voor hyprlock kleuren..."
            if kingstra-theme-apply --reload 2>/dev/null; then
                if [[ -f "$hyprlock_conf" ]]; then
                    log_ok "Hyprlock-config gegenereerd via matugen"
                    return 0
                fi
                log_warn "Matugen heeft geen hyprlock.conf geschreven — fallback wordt gebruikt"
            else
                log_warn "Matugen-run voor hyprlock mislukt — fallback wordt gebruikt"
            fi
        fi
    fi

    # Fallback: Catppuccin Mocha standaardkleuren hardcoded
    log_info "Matugen nog niet beschikbaar — Catppuccin Mocha fallback gebruiken"
    _phase10_write_fallback_hyprlock "$hyprlock_conf"
}

_phase10_write_fallback_hyprlock() {
    local dest="$1"

    cat > "$dest" << 'EOF'
# =============================================================================
# hyprlock.conf — Catppuccin Mocha fallback
# Wordt overschreven door matugen zodra kingstra-theme-apply is uitgevoerd.
# =============================================================================

background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 8
    noise = 0.0117
    contrast = 0.8916
    brightness = 0.65
    vibrancy = 0.1696
    vibrancy_darkness = 0.0
}

label {
    monitor =
    text = cmd[update:1000] echo "<b>$(date +"%H:%M")</b>"
    color = rgba(cdd6f4ff)
    font_size = 96
    font_family = JetBrains Mono Bold
    position = 0, 100
    halign = center
    valign = center
    shadow_passes = 3
    shadow_size = 5
    shadow_color = rgba(00000088)
}

label {
    monitor =
    text = cmd[update:60000] echo "$(date +"%A, %d %B")"
    color = rgba(bac2dedd)
    font_size = 22
    font_family = JetBrains Mono
    position = 0, 10
    halign = center
    valign = center
}

label {
    monitor =
    text = $USER@$HOST
    color = rgba(6c7086aa)
    font_size = 13
    font_family = JetBrains Mono
    position = 0, -60
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 320, 54
    outline_thickness = 2
    dots_size = 0.26
    dots_spacing = 0.64
    dots_center = true
    dots_rounding = -1
    outer_color = rgba(89b4faff)
    inner_color = rgba(1e1e2ecc)
    font_color = rgba(cdd6f4ff)
    fade_on_empty = true
    fade_timeout = 1000
    placeholder_text = <i><span foreground="##bac2de">Wachtwoord...</span></i>
    hide_input = false
    rounding = 18
    check_color = rgba(a6e3a1ff)
    fail_color = rgba(f38ba8ff)
    fail_text = <i>$FAIL ($ATTEMPTS)</i>
    fail_transition = 300
    capslock_color = rgba(f9e2afff)
    position = 0, -160
    halign = center
    valign = center
}
EOF
    log_ok "Hyprlock fallback-config aangemaakt: $dest"
}

_phase10_ensure_hyprlock_matugen_template() {
    local matugen_conf="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/config.toml"
    local template_src="$REPO_ROOT/config/matugen/templates/hyprlock.conf"
    local output_dest="${XDG_CONFIG_HOME:-$HOME/.config}/hyprlock/hyprlock.conf"

    ensure_dir "$(dirname "$matugen_conf")"
    ensure_dir "$(dirname "$output_dest")"

    if [[ ! -f "$matugen_conf" ]]; then
        cat > "$matugen_conf" <<EOF
scheme_type = "scheme-tonal-spot"
color_index = 0
mode = "dark"

[config]

[templates.hyprlock]
input_path = "$template_src"
output_path = "$output_dest"
EOF
        log_ok "Matugen config aangemaakt met hyprlock-template: $matugen_conf"
        return 0
    fi

    if grep -Eq '^[[:space:]]*\[templates\.hyprlock\][[:space:]]*$' "$matugen_conf"; then
        log_info "Matugen hyprlock-template bestaat al"
        return 0
    fi

    cat >> "$matugen_conf" <<EOF

[templates.hyprlock]
input_path = "$template_src"
output_path = "$output_dest"
EOF
    log_ok "Matugen hyprlock-template toegevoegd: $matugen_conf"
}

_phase10_deploy_sddm_config() {
    local sddm_conf_src="$REPO_ROOT/config/sddm/kingstra.conf"
    local sddm_conf_dest="/etc/sddm.conf.d/kingstra.conf"

    if "${DRY_RUN:-false}"; then
        log_dry "SDDM-config zou worden geplaatst: $sddm_conf_dest (vereist sudo)"
        return 0
    fi

    if [[ "${ENABLE_SDDM:-true}" != "true" ]]; then
        log_info "ENABLE_SDDM=false — SDDM-config overgeslagen"
        return 0
    fi

    if [[ ! -f "$sddm_conf_src" ]]; then
        log_warn "SDDM-config niet gevonden: $sddm_conf_src"
        return 0
    fi

    sudo mkdir -p /etc/sddm.conf.d
    sudo cp "$sddm_conf_src" "$sddm_conf_dest"
    log_ok "SDDM-config geplaatst: $sddm_conf_dest"
}

_phase10_enable_sddm() {
    if "${DRY_RUN:-false}"; then
        log_dry "SDDM-service zou worden ingeschakeld (systemctl enable sddm)"
        return 0
    fi

    if [[ "${ENABLE_SDDM:-true}" != "true" ]]; then
        log_info "ENABLE_SDDM=false — SDDM-service overgeslagen"
        return 0
    fi

    # Controleer welke display manager actief is
    # '|| true' voorkomt dat grep exit 1 (geen match) de installer stopt via set -eo pipefail
    local current_dm
    current_dm="$(systemctl list-units --type=service --state=enabled 2>/dev/null \
        | grep -E 'gdm|lightdm|ly|greetd|sddm' | awk '{print $1}' | head -1 || true)"

    if [[ -n "$current_dm" ]] && [[ "$current_dm" != "sddm.service" ]]; then
        log_warn "Andere display manager actief: $current_dm"
        log_warn "  Schakel handmatig over: sudo systemctl disable $current_dm && sudo systemctl enable sddm"
        return 0
    fi

    sudo systemctl enable sddm 2>/dev/null && \
        log_ok "SDDM-service ingeschakeld" || \
        log_warn "SDDM inschakelen mislukt — controleer de logs"
}
