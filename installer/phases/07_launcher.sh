#!/usr/bin/env bash
# =============================================================================
# Fase 07 — Launcherlaag (Walker)
# =============================================================================

phase_run() {
    log_step "Walker + Elephant installeren..."
    _phase07_install_launcher

    log_step "Elephant provider-config initialiseren..."
    _phase07_generate_elephant_config

    log_step "Walker config deployen..."
    deploy_config "walker"

    log_step "Fase 07 valideren..."
    validate_cmd walker
    validate_cmd elephant
    _phase07_validate_elephant_providers
    validate_file "$HOME/.config/walker/config.toml" "walker/config.toml"
    validate_file "$HOME/.config/walker/style.css"   "walker/style.css"
    validate_report

    log_step "Weather API configureren..."
    _phase07_weather_setup

    log_ok "Fase 07 voltooid — Walker + Elephant geïnstalleerd (Super+Ctrl+Return)."
}

_phase07_install_launcher() {
    local -a elephant_pkgs=(
        elephant-bin
        elephant-desktopapplications-bin
        elephant-providerlist-bin
        elephant-runner-bin
        elephant-symbols-bin
        elephant-calc-bin
        elephant-clipboard-bin
        elephant-files-bin
        elephant-websearch-bin
    )

    log_info "Elephant core + providers installeren: ${elephant_pkgs[*]}"
    aur_install "${elephant_pkgs[@]}"
    aur_install walker
}

_phase07_generate_elephant_config() {
    if "${DRY_RUN:-false}"; then
        log_dry "Elephant provider-config zou worden gegenereerd"
        return 0
    fi

    if ! command -v elephant &>/dev/null; then
        log_warn "elephant niet gevonden — provider-config overgeslagen"
        return 0
    fi

    elephant generate config >/dev/null 2>&1 || \
        log_warn "Kon Elephant provider-config niet genereren; Walker kan alsnog starten met provider defaults"
}

_phase07_validate_elephant_providers() {
    if "${DRY_RUN:-false}"; then
        log_dry "Elephant provider-check overgeslagen (dry-run)"
        return 0
    fi

    if ! command -v elephant &>/dev/null; then
        return 0
    fi

    local providers=""
    providers="$(elephant listproviders 2>/dev/null || true)"

    if [[ "$providers" == *desktopapplications* ]]; then
        log_ok "Elephant provider aanwezig: desktopapplications"
    else
        log_error "Elephant provider ontbreekt: desktopapplications — Walker toont dan geen applicaties"
        (( VALIDATE_ERRORS++ )) || true
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
