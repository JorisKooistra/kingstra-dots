#!/usr/bin/env bash
# =============================================================================
# kingstra-dots — Uninstaller
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$REPO_ROOT/manifest/owned-paths.txt"
BACKUP_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/backups"
INSTALL_MARKER="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/install-complete"
BACKUP_SYSTEM_SUBDIR="system"
BACKUP_METADATA_NAME="metadata.env"

DRY_RUN=false
YES=false
NO_RESTORE=false
RESTORE_BACKUP=""
SELECTED_BACKUP=""
METADATA_PREVIOUS_SHELL=""
METADATA_USER_WAS_IN_VIDEO_GROUP=""

usage() {
    cat <<EOF
Gebruik: ./uninstall.sh [opties]

Opties:
  --dry-run                 Laat zien wat er zou gebeuren
  --yes, -y                 Bevestigingsvragen overslaan
  --restore latest          Herstel de nieuwste installer-backup na verwijderen
  --restore PAD             Herstel een specifieke backup-map
  --no-restore              Alleen Kingstra-bestanden verwijderen, geen backups terugzetten
  --help, -h                Dit helpbericht tonen

Standaardgedrag:
  Zonder --no-restore probeert de uninstaller automatisch de backup van de
  huidige installatie terug te zetten (gelezen uit install-complete of anders
  de nieuwste backup-map).

Voorbeelden:
  ./uninstall.sh
  ./uninstall.sh --dry-run
  ./uninstall.sh --restore latest
  ./uninstall.sh --no-restore
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
            --no-restore)
                NO_RESTORE=true
                shift
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

file_has_all() {
    local path="$1"
    shift

    local needle
    for needle in "$@"; do
        grep -Fq "$needle" "$path" 2>/dev/null || return 1
    done
}

is_kingstra_file() {
    local path="$1"
    local base
    base="$(basename "$path")"

    [[ "$base" == kingstra-* ]] && return 0
    [[ "$path" == "$HOME/.config/systemd/user/skwd-daemon.service.d/10-kingstra-overlay.conf" ]] && return 0
    [[ "$path" == "$HOME/.local/share/kingstra/install-complete" ]] && return 0

    case "$path" in
        "$HOME/.config/xdg-desktop-portal/portals.conf")
            file_has_all "$path" \
                "default=hyprland;gtk" \
                "org.freedesktop.impl.portal.Screenshot=hyprland" \
                "org.freedesktop.impl.portal.ScreenCast=hyprland"
            return $?
            ;;
        "$HOME/.config/skwd-wall/config.json")
            file_has_all "$path" \
                '"wallpaper": "~/Pictures/Wallpapers"' \
                '"matugen": false' \
                '"compositor": "hyprland"'
            return $?
            ;;
        "$HOME/.config/hyprlock/hyprlock.conf")
            grep -Fq "hyprlock.conf — Gegenereerd door matugen. Pas dit bestand NIET aan." "$path" 2>/dev/null && return 0
            grep -Fq "hyprlock.conf — Catppuccin Mocha fallback" "$path" 2>/dev/null && return 0
            return 1
            ;;
        "$HOME/.config/gtk-3.0/settings.ini")
            file_has_all "$path" \
                "gtk-theme-name=adw-gtk3-dark" \
                "gtk-icon-theme-name=Papirus-Dark" \
                "gtk-font-name=Fira Sans 11" \
                "gtk-cursor-theme-name=Bibata-Modern-Classic"
            return $?
            ;;
        "$HOME/.config/gtk-4.0/settings.ini")
            file_has_all "$path" \
                "gtk-theme-name=adw-gtk3-dark" \
                "gtk-icon-theme-name=Papirus-Dark" \
                "gtk-font-name=Fira Sans 11" \
                "gtk-cursor-theme-name=Bibata-Modern-Classic"
            return $?
            ;;
        "$HOME/.gtkrc-2.0")
            file_has_all "$path" \
                'gtk-theme-name="adw-gtk3-dark"' \
                'gtk-icon-theme-name="Papirus-Dark"' \
                'gtk-font-name="Fira Sans 11"' \
                'gtk-cursor-theme-name="Bibata-Modern-Classic"'
            return $?
            ;;
    esac

    return 1
}

is_kingstra_dir() {
    local path="$1"

    [[ "$path" == "$HOME/.local/share/kingstra/skwd-wall-overlay" ]] && return 0
    [[ "$path" == "${XDG_CACHE_HOME:-$HOME/.cache}/kingstra" ]] && return 0
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
    local unit
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
}

latest_backup() {
    [[ -d "$BACKUP_BASE" ]] || return 1
    find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1
}

install_backup_from_marker() {
    [[ -f "$INSTALL_MARKER" ]] || return 1

    local backup_dir
    backup_dir="$(sed -n 's/^Backup:[[:space:]]*//p' "$INSTALL_MARKER" | head -n 1)"
    [[ -n "$backup_dir" ]] || return 1
    printf '%s\n' "$backup_dir"
}

resolve_backup() {
    local requested="$1"

    if [[ "$requested" == "latest" ]]; then
        latest_backup
    else
        printf '%s\n' "$requested"
    fi
}

select_restore_backup() {
    local requested=""

    if "$NO_RESTORE"; then
        log "Backup-herstel overgeslagen (--no-restore)"
        return 0
    fi

    if [[ -n "$RESTORE_BACKUP" ]]; then
        requested="$RESTORE_BACKUP"
    else
        requested="$(install_backup_from_marker || true)"
        if [[ -z "$requested" ]]; then
            requested="latest"
        fi
    fi

    SELECTED_BACKUP="$(resolve_backup "$requested" || true)"
    if [[ -z "$SELECTED_BACKUP" || ! -d "$SELECTED_BACKUP" ]]; then
        if [[ -n "$RESTORE_BACKUP" ]]; then
            warn "Opgevraagde backup niet gevonden: $RESTORE_BACKUP"
            "$DRY_RUN" && return 0
            exit 1
        fi
        warn "Geen restore-backup gevonden; uninstall gaat door zonder herstel"
        SELECTED_BACKUP=""
        return 0
    fi

    log "Restore-backup geselecteerd: $SELECTED_BACKUP"
}

load_backup_metadata() {
    local backup_dir="$1"
    local metadata_file="$backup_dir/$BACKUP_METADATA_NAME"

    [[ -f "$metadata_file" ]] || return 0

    local PREVIOUS_SHELL=""
    local USER_WAS_IN_VIDEO_GROUP=""
    # shellcheck disable=SC1090
    source "$metadata_file"

    METADATA_PREVIOUS_SHELL="${PREVIOUS_SHELL:-}"
    METADATA_USER_WAS_IN_VIDEO_GROUP="${USER_WAS_IN_VIDEO_GROUP:-}"
}

backup_has_relpath() {
    local backup_dir="$1"
    local rel_path="$2"
    [[ -n "$backup_dir" ]] || return 1
    [[ -e "$backup_dir/$rel_path" || -L "$backup_dir/$rel_path" ]]
}

restore_tree() {
    local src_root="$1"
    local dest_root="$2"
    shift 2
    local -a skip_names=("$@")

    [[ -d "$src_root" ]] || return 0

    local entry rel dest
    shopt -s nullglob dotglob
    for entry in "$src_root"/*; do
        rel="$(basename "$entry")"
        local skip_name
        for skip_name in "${skip_names[@]}"; do
            [[ -n "$skip_name" && "$rel" == "$skip_name" ]] && continue 2
        done
        dest="$dest_root/$rel"

        if [[ -d "$entry" && ! -L "$entry" ]]; then
            run mkdir -p "$dest"
            run cp -a "$entry/." "$dest/"
        else
            run mkdir -p "$(dirname "$dest")"
            run cp -a "$entry" "$dest"
        fi
    done
    shopt -u nullglob dotglob
}

restore_home_backup() {
    local backup_dir="$1"
    log "Gebruikersbestanden herstellen vanuit: $backup_dir"
    restore_tree "$backup_dir" "$HOME" "$BACKUP_SYSTEM_SUBDIR" "$BACKUP_METADATA_NAME"
}

restore_system_backup() {
    local backup_dir="$1"
    local system_dir="$backup_dir/$BACKUP_SYSTEM_SUBDIR"

    [[ -d "$system_dir" ]] || return 0

    log "Systeembestanden herstellen vanuit: $system_dir"

    local entry rel dest
    shopt -s nullglob dotglob
    for entry in "$system_dir"/*; do
        rel="$(basename "$entry")"
        dest="/$rel"

        if [[ -d "$entry" && ! -L "$entry" ]]; then
            run sudo mkdir -p "$dest"
            run sudo cp -a "$entry/." "$dest/"
        else
            run sudo mkdir -p "$(dirname "$dest")"
            run sudo cp -a "$entry" "$dest"
        fi
    done
    shopt -u nullglob dotglob
}

remove_system_paths() {
    log "Kingstra systeempaden verwijderen"

    local path
    for path in \
        "/etc/sddm.conf.d/kingstra.conf" \
        "/usr/share/sddm/themes/kingstra"; do
        if [[ -e "$path" || -L "$path" ]]; then
            run sudo rm -rf "$path"
            log "verwijderd: $path"
        fi
    done
}

cleanup_zshenv() {
    local zshenv="$HOME/.zshenv"
    local zdotdir_line='export ZDOTDIR="$HOME/.config/zsh"'

    [[ -f "$zshenv" ]] || return 0

    if [[ -n "$SELECTED_BACKUP" ]]; then
        if backup_has_relpath "$SELECTED_BACKUP" ".zshenv"; then
            return 0
        fi
    fi

    grep -Fq "$zdotdir_line" "$zshenv" 2>/dev/null || return 0

    local tmp_file
    tmp_file="$(mktemp)"
    grep -vxF "$zdotdir_line" "$zshenv" > "$tmp_file" || true

    if [[ ! -s "$tmp_file" ]]; then
        run rm -f "$zshenv"
        log "verwijderd: ~/.zshenv"
    else
        run cp "$tmp_file" "$zshenv"
        log "ZDOTDIR-regel verwijderd uit ~/.zshenv"
    fi

    rm -f "$tmp_file"
}

cleanup_default_wallpaper() {
    local default_src="$REPO_ROOT/assets/wallpapers/wallhaven-mlwz78.png"
    local default_dest="$HOME/Pictures/Wallpapers/wallhaven-mlwz78.png"

    [[ -f "$default_src" && -f "$default_dest" ]] || return 0

    if [[ -n "$SELECTED_BACKUP" ]]; then
        if backup_has_relpath "$SELECTED_BACKUP" "Pictures/Wallpapers/wallhaven-mlwz78.png"; then
            return 0
        fi
    fi

    if cmp -s "$default_src" "$default_dest"; then
        run rm -f "$default_dest"
        log "verwijderd: ~/Pictures/Wallpapers/wallhaven-mlwz78.png"
    fi
}

remove_dir_if_empty() {
    local path="$1"
    [[ -d "$path" ]] || return 0
    if "$DRY_RUN"; then
        run rmdir "$path"
        log "lege map zou worden verwijderd: ${path/#$HOME/\~}"
        return 0
    fi
    rmdir "$path" 2>/dev/null && log "lege map verwijderd: ${path/#$HOME/\~}" || true
}

restore_account_state() {
    if [[ -n "$METADATA_PREVIOUS_SHELL" ]] && command -v getent >/dev/null 2>&1; then
        local current_shell
        current_shell="$(getent passwd "$USER" | cut -d: -f7)"
        if [[ -n "$current_shell" && "$current_shell" != "$METADATA_PREVIOUS_SHELL" ]]; then
            run chsh -s "$METADATA_PREVIOUS_SHELL"
            log "Login-shell hersteld naar: $METADATA_PREVIOUS_SHELL"
        fi
    fi

    if [[ "$METADATA_USER_WAS_IN_VIDEO_GROUP" == "false" ]]; then
        if id -nG "$USER" 2>/dev/null | grep -qw video; then
            run sudo gpasswd -d "$USER" video
            log "Gebruiker verwijderd uit groep 'video'"
        fi
    fi
}

cleanup_generated_paths() {
    cleanup_zshenv
    cleanup_default_wallpaper
    remove_dir_if_empty "$HOME/.config/hyprlock"
    remove_dir_if_empty "$HOME/.config/skwd-wall"
}

main() {
    parse_args "$@"

    log "Repo: $REPO_ROOT"
    "$DRY_RUN" && warn "Dry-run actief: er worden geen wijzigingen uitgevoerd."

    if ! confirm "Kingstra-dots deinstalleren voor gebruiker $USER?"; then
        log "Geannuleerd."
        exit 0
    fi

    select_restore_backup
    [[ -n "$SELECTED_BACKUP" ]] && load_backup_metadata "$SELECTED_BACKUP"

    stop_session
    disable_user_services
    remove_owned_paths
    remove_system_paths

    if [[ -n "$SELECTED_BACKUP" ]]; then
        restore_system_backup "$SELECTED_BACKUP"
        restore_home_backup "$SELECTED_BACKUP"
    fi

    restore_account_state
    cleanup_generated_paths

    log "Deinstallatie voltooid. Herstart of log opnieuw in om shell, PAM en sessie volledig te verversen."
}

main "$@"
