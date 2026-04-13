#!/usr/bin/env bash
# =============================================================================
# Fase 15 — Eindvalidatie en afronding
# =============================================================================
# Doel:
#   - Alle kritieke bestanden en commando's valideren
#   - Systemd-services controleren
#   - install-complete marker schrijven
#   - Post-installatie instructies afdrukken
# =============================================================================

phase_run() {
    log_step "Kritieke commando's valideren..."
    _phase15_validate_commands

    log_step "Configuratiebestanden valideren..."
    _phase15_validate_configs

    log_step "Symlinks valideren..."
    _phase15_validate_links

    log_step "Installer-marker schrijven..."
    _phase15_write_marker

    validate_report

    log_ok "Fase 15 voltooid — Kingstra-dots is volledig geïnstalleerd."
    _phase15_print_next_steps
    _phase15_prompt_reboot
}

# ---------------------------------------------------------------------------

_phase15_validate_commands() {
    # Kern
    validate_cmd hyprland
    validate_cmd hyprctl
    validate_cmd awww
    validate_cmd hypridle
    validate_cmd hyprlock
    # Shell
    validate_cmd zsh
    validate_cmd kitty
    validate_cmd oh-my-posh
    validate_cmd fastfetch
    # UI-laag
    validate_cmd quickshell
    validate_cmd swaync
    validate_cmd walker
    validate_cmd swayosd-server
    # Thema
    validate_cmd matugen
    # Apps
    validate_cmd nautilus
    validate_cmd yazi
    validate_cmd cliphist
    validate_cmd wtype
    validate_cmd grim
    validate_cmd slurp
    validate_cmd playerctl
    validate_cmd btop
    validate_cmd fzf
    # Netwerk
    validate_cmd nmcli
    validate_cmd bluetoothctl
}

_phase15_validate_configs() {
    # Hyprland
    validate_file "$HOME/.config/hypr/hyprland.conf"                   "hyprland.conf"
    validate_file "$HOME/.config/hypr/colors.conf"                     "hypr/colors.conf"
    validate_file "$HOME/.config/hypr/conf.d/72-hardware.conf"         "72-hardware.conf"
    validate_file "$HOME/.config/hypr/scripts/lock.sh"                 "hypr/scripts/lock.sh"
    validate_file "$HOME/.config/hypr/scripts/lid-lock.sh"             "hypr/scripts/lid-lock.sh"
    # Shell
    validate_file "$HOME/.config/kitty/kitty.conf"                     "kitty.conf"
    validate_file "$HOME/.config/zsh/kingstra.omp.toml"                "kingstra.omp.toml"
    validate_file "$HOME/.zshenv"                                       ".zshenv (ZDOTDIR)"
    # Quickshell
    validate_file "$HOME/.config/quickshell/shell.qml"                 "shell.qml"
    validate_file "$HOME/.config/quickshell/colors.json"               "colors.json"
    # Matugen
    validate_file "$HOME/.config/matugen/config.toml"                  "matugen/config.toml"
    validate_file "$HOME/.local/bin/kingstra-theme-apply"              "kingstra-theme-apply"
    validate_file "$HOME/.local/bin/kingstra-matugen-run"              "kingstra-matugen-run"
    validate_file "$HOME/.local/bin/kingstra-theme-update"             "kingstra-theme-update"
    validate_file "$HOME/.local/bin/kingstra-touch-detect"             "kingstra-touch-detect"
    validate_file "$HOME/.local/bin/kingstra-wallpaper"                "kingstra-wallpaper"
    validate_file "$HOME/.local/bin/kingstra-skwd-wallpaper-sync"      "kingstra-skwd-wallpaper-sync"
    # Session
    validate_file "$HOME/.config/hypridle/hypridle.conf"               "hypridle.conf"
    validate_file "$HOME/.config/hyprlock/hyprlock.conf"               "hyprlock.conf"
    # SwayNC / Walker
    validate_file "$HOME/.config/swaync/config.jsonc"                  "swaync/config.jsonc"
    validate_file "$HOME/.config/walker/config.toml"                   "walker/config.toml"
    # Yazi
    validate_file "$HOME/.config/yazi/yazi.toml"                       "yazi.toml"
    # Netwerk
    validate_file "$HOME/.config/systemd/user/kingstra-resume.service" "kingstra-resume.service"
    # Wallpaper
    validate_dir  "$HOME/Pictures/Wallpapers"                          "Pictures/Wallpapers"
}

_phase15_validate_links() {
    local cfg="$REPO_ROOT/config"
    validate_link "$HOME/.config/hypr"       "$cfg/hypr"       "~/.config/hypr"
    validate_link "$HOME/.config/quickshell" "$cfg/quickshell" "~/.config/quickshell"
    validate_link "$HOME/.config/matugen"    "$cfg/matugen"    "~/.config/matugen"
    validate_link "$HOME/.config/swaync"     "$cfg/swaync"     "~/.config/swaync"
    validate_link "$HOME/.config/walker"     "$cfg/walker"     "~/.config/walker"
    validate_link "$HOME/.config/kitty"      "$cfg/kitty"      "~/.config/kitty"
    validate_link "$HOME/.config/yazi"       "$cfg/yazi"       "~/.config/yazi"
    validate_link "$HOME/.config/hyprpaper"  "$cfg/hyprpaper"  "~/.config/hyprpaper"
    validate_link "$HOME/.config/hypridle"   "$cfg/hypridle"   "~/.config/hypridle"
    validate_link "$HOME/.local/bin/kingstra-theme-apply" \
                  "$cfg/shared/scripts/matugen-apply.sh"  "kingstra-theme-apply"
    validate_link "$HOME/.local/bin/kingstra-theme-update" \
                  "$cfg/shared/scripts/kingstra-theme-update.py"  "kingstra-theme-update"
    validate_link "$HOME/.local/bin/kingstra-matugen-run" \
                  "$cfg/shared/scripts/kingstra-matugen-run"  "kingstra-matugen-run"
    validate_link "$HOME/.local/bin/kingstra-touch-detect" \
                  "$cfg/shared/scripts/kingstra-touch-detect"  "kingstra-touch-detect"
    validate_link "$HOME/.local/bin/kingstra-wallpaper" \
                  "$REPO_ROOT/config/wallpaper/kingstra-wallpaper" "kingstra-wallpaper"
    validate_link "$HOME/.local/bin/kingstra-skwd-wallpaper-sync" \
                  "$REPO_ROOT/config/wallpaper/kingstra-skwd-wallpaper-sync" "kingstra-skwd-wallpaper-sync"
}

_phase15_write_marker() {
    local marker_dir="$HOME/.local/share/kingstra"
    local marker_file="$marker_dir/install-complete"

    if "${DRY_RUN:-false}"; then
        log_dry "Install-marker zou worden geschreven: $marker_file"
        return 0
    fi

    ensure_dir "$marker_dir"
    {
        echo "Geïnstalleerd op: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "GPU:         ${DETECT_GPU:-onbekend}"
        echo "Laptop:      ${DETECT_IS_LAPTOP:-false}"
        echo "Touchpad:    ${DETECT_HAS_TOUCHPAD:-false}"
        echo "Fingerprint: ${DETECT_HAS_FINGERPRINT:-false}"
        echo "Repo:        $REPO_ROOT"
    } > "$marker_file"

    log_ok "Installatie-marker geschreven: $marker_file"
}

_phase15_print_next_steps() {
    printf '\n'
    printf '\033[1;32m╔══════════════════════════════════════════════════════╗\n'
    printf '║          Kingstra-dots — Installatie voltooid        ║\n'
    printf '╚══════════════════════════════════════════════════════╝\033[0m\n'
    printf '\n'
    printf '\033[1mVolgende stappen:\033[0m\n\n'
    printf '  1. Start Hyprland (vanuit TTY):\n'
    printf '       Hyprland\n\n'
    printf '  2. Stel een wallpaper in (triggert automatisch Matugen):\n'
    printf '       kingstra-wallpaper set ~/Pictures/Wallpapers/foto.png\n'
    printf '       kingstra-wallpaper pick    # interactieve kiezer\n\n'
    printf '  3. SDDM activeren (display manager, indien niet automatisch):\n'
    printf '       sudo systemctl enable --now sddm\n\n'
    if [[ "${DETECT_HAS_FINGERPRINT:-false}" == "true" ]]; then
        printf '  4. Vingerafdruk inschrijven:\n'
        printf '       fprintd-enroll\n\n'
    fi
    printf '\033[1mHandige commando'"'"'s:\033[0m\n\n'
    printf '  kingstra-wallpaper set <bestand>   Wallpaper + Matugen-kleuren\n'
    printf '  kingstra-wallpaper random          Willekeurig wallpaper\n'
    printf '  kingstra-wallpaper pick            Interactieve kiezer (fzf)\n'
    printf '  kingstra-theme-apply --reload      Kleuren hertoepassen\n'
    printf '  qs ipc call stats toggle           Systeem-popup\n'
    printf '  qs ipc call power toggle           Power-menu\n'
    printf '\n'
    printf '\033[1mLog:\033[0m    ~/.local/share/kingstra/install.log\n'
    printf '\033[1mBackups:\033[0m ~/.local/share/kingstra/backups/\n'
    printf '\n'
}

_phase15_prompt_reboot() {
    if "${DRY_RUN:-false}"; then
        log_dry "Herstart-prompt zou verschijnen"
        return 0
    fi

    printf '\033[1;33m  Herstart aanbevolen\033[0m om SDDM en alle services correct op te starten.\n\n'

    local answer
    read -r -p "  Nu herstarten? [j/N] " answer
    case "${answer,,}" in
        j|ja|y|yes)
            log_ok "Systeem wordt herstart..."
            sleep 1
            sudo reboot
            ;;
        *)
            printf '\n'
            log_info "Herstart later met: sudo reboot"
            printf '\n'
            ;;
    esac
}
