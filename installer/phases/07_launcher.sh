#!/usr/bin/env bash
# =============================================================================
# Fase 07 — Launcherlaag (Walker)
# =============================================================================

phase_run() {
    log_step "Walker + Elephant installeren..."
    _phase07_install_launcher

    log_step "Walker config deployen..."
    deploy_config "walker"

    log_step "Fase 07 valideren..."
    validate_cmd walker
    validate_cmd elephant
    validate_file "$HOME/.config/walker/config.toml" "walker/config.toml"
    validate_file "$HOME/.config/walker/style.css"   "walker/style.css"
    validate_report

    log_step "Weather API configureren..."
    _phase07_weather_setup

    log_ok "Fase 07 voltooid — Walker + Elephant geïnstalleerd (Super+Ctrl+Return)."
}

_phase07_install_launcher() {
    local elephant_pkg="elephant-bin"

    if _phase07_has_installed_source_elephant; then
        log_warn "Elephant bronpakket staat al geïnstalleerd; gebruik bestaande route om conflicts te voorkomen"
        elephant_pkg="elephant"
    else
        _phase07_warn_source_conflicts
    fi

    if aur_install "$elephant_pkg" && aur_install walker; then
        return 0
    fi

    if [[ "$elephant_pkg" == "elephant-bin" ]]; then
        log_warn "Installatie van elephant-bin + walker faalde; fallback naar elephant + walker"
        log_warn "Dit is trager, maar voorkomt dat een clean install hard stopt op de bin-package."
        aur_install elephant && aur_install walker
        return $?
    fi

    return 1
}

_phase07_has_installed_source_elephant() {
    local pkg
    for pkg in elephant elephant-desktopapplications elephant-providerlist elephant-runner elephant-symbols elephant-calc elephant-clipboard elephant-files; do
        if pacman -Qi "$pkg" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

_phase07_warn_source_conflicts() {
    local -a conflicts=()
    local pkg

    for pkg in elephant elephant-desktopapplications elephant-providerlist elephant-runner elephant-symbols elephant-calc elephant-clipboard elephant-files; do
        if pacman -Qi "$pkg" >/dev/null 2>&1; then
            conflicts+=("$pkg")
        fi
    done

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        log_warn "Bestaande Elephant bronpakketten gevonden: ${conflicts[*]}"
        log_warn "Deze conflicteren met elephant-bin, de snelle prebuilt variant die fase 7 nu gebruikt."
        log_warn "Verwijder ze eerst handmatig als yay blijft melden dat elephant-bin en elephant conflicteren:"
        log_warn "  yay -Rns ${conflicts[*]}"
    fi
}

_phase07_weather_setup() {
    local env_file="$HOME/.config/quickshell/calendar/.env"

    if [[ -f "$env_file" ]]; then
        log_ok "Weather .env bestaat al — overgeslagen"
        return 0
    fi

    if "${DRY_RUN:-false}"; then
        log_dry "Weather .env zou worden aangemaakt"
        return 0
    fi

    log_info "De kalender-widget kan live weer tonen via OpenWeatherMap."
    log_info "Haal een gratis API key op: https://openweathermap.org/api"
    log_info "Je kunt dit later ook instellen via Super+G → Weather tab."

    prompt_input "OpenWeatherMap API key (leeg = overslaan)"
    local api_key="$PROMPT_RESULT"

    if [[ -z "$api_key" ]]; then
        log_info "Geen API key opgegeven — weer-widget toont dummy data."
        log_info "Stel later in via Super+G → Weather tab."
        return 0
    fi

    prompt_input "Breedtegraad (bijv. 52.3676)" "52.3676"
    local lat="$PROMPT_RESULT"
    prompt_input "Lengtegraad (bijv. 4.9041)" "4.9041"
    local lon="$PROMPT_RESULT"
    prompt_choice "Eenheid" "metric" "imperial" "standard"
    local unit="$PROMPT_RESULT"

    mkdir -p "$(dirname "$env_file")"
    cat > "$env_file" <<EOF
OPENWEATHER_KEY=$api_key
OPENWEATHER_UNIT=$unit
OPENWEATHER_LAT=$lat
OPENWEATHER_LON=$lon
OPENWEATHER_CITY_ID=
EOF
    log_ok "Weather configuratie opgeslagen in $env_file"
}
