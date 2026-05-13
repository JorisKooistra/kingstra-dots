#!/usr/bin/env bash
# =============================================================================
# kingstra-dots — Uninstaller
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$REPO_ROOT/manifest/owned-paths.txt"
BACKUP_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/backups"
DRY_RUN=false
YES=false
RESTORE_BACKUP=""

usage() {
    cat <<EOF
Gebruik: ./uninstall.sh [opties]

Opties:
  --dry-run                 Laat zien wat er zou gebeuren
  --yes, -y                 Bevestigingsvragen overslaan
  --restore latest          Herstel de nieuwste installer-backup na verwijderen
  --restore PAD             Herstel een specifieke backup-map
  --help, -h                Dit helpbericht tonen

Voorbeelden:
  ./uninstall.sh
  ./uninstall.sh --dry-run
  ./uninstall.sh --restore latest
EOF
}

log() {
    printf '[kingstra-uninstall] %s\n' "$*"
}

warn() {
    printf '[kingstra-uninstall] WARN: %s\n' "$*" >&2
}

run() {
    if "$DRY_RUN"; then
        printf '[kingstra-uninstall] DRY:'
        printf ' %q' "$@"
        printf '\n'
        return 0
    fi
    "$@"
}

confirm() {
    local question="$1"
    "$YES" && return 0
    printf '%s [j/N] ' "$question"
    local answer
    read -r answer
    case "${answer,,}" in
        j|ja|y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --yes|-y)
                YES=true
                shift
                ;;
            --restore)
                RESTORE_BACKUP="${2:-}"
                [[ -n "$RESTORE_BACKUP" ]] || { warn "--restore vereist een waarde"; exit 2; }
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                warn "Onbekend argument: $1"
                usage
                exit 2
                ;;
        esac
    done
}

expand_path() {
    local path="$1"
    printf '%s\n' "${path/#\~/$HOME}"
}

path_points_into_repo() {
    local path="$1"
    [[ -L "$path" ]] || return 1

    local target
    target="$(readlink -f "$path" 2>/dev/null || true)"
    [[ -n "$target" && "$target" == "$REPO_ROOT"* ]]
}

is_kingstra_file() {
    local path="$1"
    local base
    base="$(basename "$path")"

    [[ "$base" == kingstra-* ]] && return 0
    [[ "$path" == "$HOME/.config/systemd/user/skwd-daemon.service.d/10-kingstra-overlay.conf" ]] && return 0
    [[ "$path" == "$HOME/.local/share/kingstra/install-complete" ]] && return 0
    return 1
}

is_kingstra_dir() {
    local path="$1"

    [[ "$path" == "$HOME/.local/share/kingstra/skwd-wall-overlay" ]] && return 0
    path_points_into_repo "$path"
}

stop_session() {
    log "Kingstra sessieprocessen stoppen"

    if [[ -x "$HOME/.local/bin/kingstra-session-start" ]]; then
        run "$HOME/.local/bin/kingstra-session-start" stop || true
    fi

    local pattern
    for pattern in \
        "quickshell.*$HOME/.config/quickshell/TopBar.qml" \
        "quickshell.*$HOME/.config/quickshell/Main.qml" \
        "qs.*$HOME/.config/quickshell/overview/shell.qml" \
        "focus_daemon.py" \
        "walker --gapplication-service" \
        "swayosd-server" \
        "swaync$" \
        "hypridle$" \
        "awww-daemon"; do
        if pgrep -f "$pattern" >/dev/null 2>&1; then
            run pkill -f "$pattern" || true
        fi
    done
}

disable_user_services() {
    command -v systemctl >/dev/null 2>&1 || return 0

    log "Kingstra user-services uitschakelen"
    for unit in kingstra-resume.service kingstra-lid-lock.service skwd-daemon.service; do
        if "$DRY_RUN"; then
            run systemctl --user disable --now "$unit"
        else
            systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
        fi
    done
    if "$DRY_RUN"; then
        run systemctl --user daemon-reload
    else
        systemctl --user daemon-reload >/dev/null 2>&1 || true
    fi
}

remove_owned_paths() {
    [[ -f "$MANIFEST" ]] || { warn "Manifest ontbreekt: $MANIFEST"; return 1; }

    log "Kingstra-owned paden verwijderen"

    local raw_path mode path
    while IFS='|' read -r raw_path mode || [[ -n "$raw_path" ]]; do
        [[ -z "$raw_path" || "$raw_path" == \#* ]] && continue

        path="$(expand_path "$raw_path")"
        [[ -e "$path" || -L "$path" ]] || continue

        case "$mode" in
            symlink)
                if path_points_into_repo "$path"; then
                    run rm -rf "$path"
                    log "verwijderd: $raw_path"
                else
                    warn "overgeslagen, geen Kingstra-symlink: $raw_path"
                fi
                ;;
            file)
                if [[ -f "$path" || -L "$path" ]] && is_kingstra_file "$path"; then
                    run rm -f "$path"
                    log "verwijderd: $raw_path"
                else
                    warn "overgeslagen, niet herkenbaar als Kingstra-file: $raw_path"
                fi
                ;;
            dir)
                if [[ -d "$path" || -L "$path" ]] && is_kingstra_dir "$path"; then
                    run rm -rf "$path"
                    log "verwijderd: $raw_path"
                else
                    warn "overgeslagen, niet herkenbaar als Kingstra-dir: $raw_path"
                fi
                ;;
            *)
                warn "Onbekende manifestmodus '$mode' voor $raw_path"
                ;;
        esac
    done < "$MANIFEST"

    return 0
}

latest_backup() {
    [[ -d "$BACKUP_BASE" ]] || return 1
    find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1
}

resolve_backup() {
    local requested="$1"

    if [[ "$requested" == "latest" ]]; then
        latest_backup
    else
        printf '%s\n' "$requested"
    fi
}

restore_backup() {
    local requested="$1"
    local backup_dir
    backup_dir="$(resolve_backup "$requested" || true)"

    [[ -n "$backup_dir" && -d "$backup_dir" ]] || {
        warn "Backup niet gevonden: $requested"
        "$DRY_RUN" && return 0
        return 1
    }

    log "Backup herstellen: $backup_dir"
    run cp -a "$backup_dir/." "$HOME/"
}

maybe_prompt_restore() {
    [[ -z "$RESTORE_BACKUP" ]] || return 0
    "$YES" && return 0

    local latest
    latest="$(latest_backup || true)"
    [[ -n "$latest" ]] || return 0

    if confirm "Nieuwste backup herstellen na uninstall? ($latest)"; then
        RESTORE_BACKUP="$latest"
    fi
}

main() {
    parse_args "$@"

    log "Repo: $REPO_ROOT"
    "$DRY_RUN" && warn "Dry-run actief: er worden geen wijzigingen uitgevoerd."

    if ! confirm "Kingstra-dots deinstalleren voor gebruiker $USER?"; then
        log "Geannuleerd."
        exit 0
    fi

    maybe_prompt_restore
    stop_session
    disable_user_services
    remove_owned_paths

    if [[ -n "$RESTORE_BACKUP" ]]; then
        restore_backup "$RESTORE_BACKUP"
    fi

    log "Deinstallatie voltooid. Herstart of log opnieuw in om sessie-autostart volledig te verversen."
}

main "$@"
