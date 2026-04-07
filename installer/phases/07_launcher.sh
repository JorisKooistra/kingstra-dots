#!/usr/bin/env bash
# =============================================================================
# Fase 07 — Launcherlaag (Walker)
# =============================================================================

phase_run() {
    log_step "Walker + Elephant installeren..."
    aur_install walker-bin
    aur_install elephant
    aur_install elephant-desktopapplications-bin
    aur_install elephant-providerlist-bin

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
