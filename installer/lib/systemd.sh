#!/usr/bin/env bash
# =============================================================================
# systemd.sh — Systemd services en user-services beheren
# =============================================================================

# Enable + start een systeem-service
service_enable() {
    local service="$1"
    log_step "Systemd service enablen: $service"
    run_cmd sudo systemctl enable --now "$service"
}

# Enable + start een user-service
user_service_enable() {
    local service="$1"
    log_step "User service enablen: $service"
    run_cmd systemctl --user enable --now "$service"
}

# Disable een systeem-service
service_disable() {
    local service="$1"
    log_step "Systemd service disablen: $service"
    run_cmd sudo systemctl disable --now "$service" 2>/dev/null || true
}

# Disable een user-service
user_service_disable() {
    local service="$1"
    log_step "User service disablen: $service"
    run_cmd systemctl --user disable --now "$service" 2>/dev/null || true
}

# Installeer en enable services vanuit manifest
# Formaat: "system:<service>" of "user:<service>"
services_from_manifest() {
    local manifest_file="$1"

    if [[ ! -f "$manifest_file" ]]; then
        log_warn "Services-manifest niet gevonden: $manifest_file"
        return 0
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" == system:* ]]; then
            service_enable "${line#system:}"
        elif [[ "$line" == user:* ]]; then
            user_service_enable "${line#user:}"
        else
            log_warn "Onbekend service-formaat: $line"
        fi
    done < "$manifest_file"
}
