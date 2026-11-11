#!/usr/bin/env bash
# =============================================================================
# Fase 11 — Apps en dagelijkse tools
# =============================================================================
# Doel:
#   - Dagelijkse apps installeren (nautilus, cliphist, playerctl, screenshot-tools)
#   - Yazi bestandsbeheerder + config deployen
#   - Optionele apps op basis van profielvlaggen (Spicetify, Vesktop)
#   - Polkit-agent + authenticatielaag valideren
#   - Screenshot-toolchain valideren (grim + slurp + satty + wl-clipboard)
# =============================================================================

phase_run() {
    log_step "Bestandsbeheerder installeren..."
    pacman_install nautilus
    pacman_install file-roller          # archiefbeheer in Nautilus
    pacman_install gvfs                 # trash/MTP/samba support
    pacman_install gvfs-mtp             # MTP (telefoons via USB)
    pacman_install ffmpegthumbnailer    # video-miniaturen in Nautilus
    _phase11_default_file_manager

    log_step "Klembord installeren..."
    pacman_install cliphist
    pacman_install wl-clipboard         # wl-copy / wl-paste
    pacman_install wtype                # fallback voor automatisch plakken na cliphist

    log_step "Media-tools installeren..."
    pacman_install playerctl
    pacman_install mpv                  # videospeler (ook voor yazi preview)
    pacman_install picard               # MusicBrainz metadata-editor
    pacman_install qt5-wayland          # Picard/PyQt5 Wayland-platformplugin

    log_step "Screenshot-toolchain installeren..."
    pacman_install grim
    pacman_install slurp
    aur_install_optional satty
    pacman_install wf-recorder          # schermopname (vastleg-studio, Super+Shift+R)
    pacman_install hyprpicker           # kleur kiezen
    pacman_install tesseract tesseract-data-nld tesseract-data-eng   # tekst uit beeld

    log_step "Authenticatieagent installeren..."
    pacman_install polkit-gnome

    log_step "Netwerkbeheer GUI installeren..."
    pacman_install network-manager-applet
    pacman_install blueman

    log_step "Schijven automatisch koppelen..."
    pacman_install udisks2
    _phase11_setup_disks

    log_step "Logitech-muisknoppen (logiops)..."
    _phase11_setup_logiops

    log_step "Yazi bestandsbeheerder installeren..."
    pacman_install yazi
    pacman_install p7zip                # uitpakken vanuit yazi (7z, xz, bzip2...)
    pacman_install unzip zip            # zip-bestanden vanuit yazi

    log_step "Docker alleen bij gebruik starten..."
    _phase11_docker_on_demand

    log_step "Yazi-config deployen..."
    deploy_config "yazi"
    _phase11_init_yazi_theme_file

    log_step "Firefox-profiel optimalisaties deployen..."
    _phase11_setup_firefox

    log_step "Dicteren (whisper.cpp, lokaal)..."
    _phase11_setup_dictation

    log_step "Optionele apps installeren..."
    _phase11_optional_apps

    log_step "Dagelijkse apps in thema (foto, pdf, tekst, video)..."
    _phase11_daily_apps
    _phase11_default_apps
    _phase11_disk_bookmarks
    _phase11_apps_sync

    log_step "Pdf ondertekenen (Xournal++)..."
    _phase11_pdf_sign

    log_step "Telefoon koppelen (KDE Connect)..."
    # Geen autostart: de dienst start via D-Bus zodra het paneel Telefoon
    # (of kdeconnect-cli) hem nodig heeft en blijft dan de sessie draaien.
    pacman_install_optional kdeconnect
    pacman_install_optional zenity      # bestand kiezen om naar de telefoon te sturen
    pacman_install_optional sshfs       # bestanden van de telefoon bladeren (Telefoon > Bladeren)
    pacman_install_optional scrcpy      # telefoonscherm op de pc (Telefoon > Scherm op pc), brengt adb mee
    pacman_install_optional wayvnc      # pc-scherm op de telefoon (Telefoon > Pc op telefoon, via Tailscale)

    log_step "Fase 11 valideren..."
    validate_cmd nautilus
    validate_cmd cliphist
    validate_cmd wl-copy
    validate_cmd wtype
    validate_cmd playerctl
    validate_cmd picard
    validate_file "/usr/lib/qt/plugins/platforms/libqwayland-generic.so" "Qt5 Wayland platformplugin"
    validate_cmd grim
    validate_cmd slurp
    validate_cmd yazi
    validate_file "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1" "polkit-gnome"
    validate_dir  "$HOME/.config/yazi" "yazi config"
    validate_file "$HOME/.config/yazi/yazi.toml"    "yazi.toml"
    validate_file "$HOME/.config/yazi/keymap.toml"  "yazi keymap.toml"
    validate_file "$HOME/.config/yazi/theme.toml"   "yazi theme.toml"
    validate_file "$HOME/.config/firefox/user.js"   "firefox/user.js"
    validate_file "$HOME/.local/bin/kingstra-firefox-optimize" "kingstra-firefox-optimize"
    validate_file "$HOME/.local/bin/kingstra-disks" "kingstra-disks"
    validate_report

    log_ok "Fase 11 voltooid — Apps en dagelijkse tools beschikbaar."
    log_info "Bestandsbeheer:  yazi (Super+E opent nautilus, yazi staat in het toetsenbordmenu)"
    log_info "Klembord:        Super+V — cliphist via Walker, plakt selectie"
    log_info "Screenshot:      Print / Super+Print / Shift+Print"
}

# ---------------------------------------------------------------------------
# Vaste set dagelijkse apps die het thema volgen (libadwaita: kleuren, licht/
# donker en vorm via kingstra-apps-sync). Los geïnstalleerd, zodat een
# ontbrekend pakket de rest niet tegenhoudt.
_phase11_daily_apps() {
    local pkg
    for pkg in loupe papers gnome-text-editor showtime; do
        pacman_install "$pkg" || log_warn "$pkg niet geïnstalleerd"
    done
}

# Standaard-apps per bestandssoort. Eenmalig per versie van deze lijst, zodat
# een eigen keuze daarna (Openen met → Altijd) bij een update blijft staan.
_phase11_default_apps() {
    local marker="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra/default-apps-v1"
    if "${DRY_RUN:-false}"; then
        log_dry "Loupe, Papers, Teksteditor en Showtime zouden standaard worden"
        return 0
    fi
    [[ -f "$marker" ]] && { log_ok "Standaard-apps al gezet (eigen keuzes blijven)"; return 0; }
    command -v xdg-mime &>/dev/null || return 0

    local -A apps=(
        [org.gnome.Loupe.desktop]="image/jpeg image/png image/gif image/webp image/bmp image/tiff image/svg+xml image/avif image/heic image/x-icon"
        [org.gnome.Papers.desktop]="application/pdf"
        [org.gnome.TextEditor.desktop]="text/plain text/markdown text/x-log text/csv"
        [org.gnome.Showtime.desktop]="video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg video/ogg"
    )
    local desktop
    for desktop in "${!apps[@]}"; do
        if [[ -f "/usr/share/applications/$desktop" ]]; then
            # shellcheck disable=SC2086 # de mime-lijst is bewust gesplitst
            xdg-mime default "$desktop" ${apps[$desktop]} 2>/dev/null \
                || log_warn "xdg-mime: $desktop niet als standaard gezet"
        else
            log_warn "$desktop ontbreekt; standaard niet gezet"
        fi
    done
    mkdir -p "$(dirname "$marker")" && touch "$marker"
    log_ok "Foto's: Loupe, pdf: Papers, tekst: Teksteditor, video: Showtime"
}

# "PDF ondertekenen" in Openen met (rechtsklik in Nautilus) en de launcher.
# Papers blijft de standaard pdf-app; dit is alleen een extra keuze.
_phase11_pdf_sign() {
    local src="$REPO_ROOT/config/shared/scripts/kingstra-pdf-sign"
    local desktop="${XDG_DATA_HOME:-$HOME/.local/share}/applications/kingstra-pdf-sign.desktop"
    pacman_install_optional xournalpp
    if "${DRY_RUN:-false}"; then
        log_dry "kingstra-pdf-sign en $desktop zouden worden geplaatst"
        return 0
    fi
    ensure_dir "$HOME/.local/bin"
    chmod +x "$src"
    deploy_link "$src" "$HOME/.local/bin/kingstra-pdf-sign"
    ensure_dir "$(dirname "$desktop")"
    cat > "$desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=PDF ondertekenen
Comment=Handtekening op een pdf zetten en als nieuwe pdf opslaan
Exec=$HOME/.local/bin/kingstra-pdf-sign %f
Icon=document-edit-sign
Terminal=false
MimeType=application/pdf;
Categories=Office;
Keywords=handtekening;tekenen;sign;signature;pdf;
NoDisplay=false
DESKTOP
    command -v update-desktop-database &>/dev/null \
        && update-desktop-database "$(dirname "$desktop")" 2>/dev/null || true
    log_ok "PDF ondertekenen staat in Openen met en in de launcher"
}

# Data-schijven (/mnt/data*) als vaste plek in de zijbalk van Nautilus en
# elke open-/opslaan-dialoog. Bestaande bladwijzers blijven staan.
_phase11_disk_bookmarks() {
    local bookmarks="$HOME/.config/gtk-3.0/bookmarks"
    local mnt label
    if "${DRY_RUN:-false}"; then
        log_dry "Data-schijven zouden als bladwijzer worden toegevoegd"
        return 0
    fi
    command -v findmnt &>/dev/null || return 0
    mkdir -p "$(dirname "$bookmarks")"
    touch "$bookmarks"
    for mnt in /mnt/data*; do
        [[ -d "$mnt" ]] && findmnt -rn "$mnt" &>/dev/null || continue
        grep -q "^file://$mnt\( \|$\)" "$bookmarks" && continue
        label="$(findmnt -rn -o LABEL "$mnt" 2>/dev/null | head -n1)"
        [[ -n "$label" ]] || label="$(basename "$mnt")"
        printf 'file://%s %s\n' "$mnt" "$label" >> "$bookmarks"
        log_ok "Bladwijzer: $label ($mnt)"
    done
}

# Eén keer de app-laag bijwerken: app-profiel, vormlaag, VS Code-thema
# (installeert de lokale extensie), Vesktop en mapiconen.
_phase11_apps_sync() {
    if "${DRY_RUN:-false}"; then
        log_dry "kingstra-apps-sync zou draaien"
        return 0
    fi
    python3 "$REPO_ROOT/config/shared/scripts/kingstra-apps-sync" \
        && log_ok "Apps volgen het actieve thema" \
        || log_warn "kingstra-apps-sync mislukt; volgt bij de volgende themawissel"
}

# ---------------------------------------------------------------------------
# Nautilus als standaard voor mappen ("Map openen" vanuit udiskie, browser, ...)
_phase11_default_file_manager() {
    if "${DRY_RUN:-false}"; then
        log_dry "Nautilus zou standaard worden voor inode/directory"
        return 0
    fi
    if command -v xdg-mime &>/dev/null; then
        xdg-mime default org.gnome.Nautilus.desktop inode/directory 2>/dev/null \
            && log_ok "Nautilus is standaard voor mappen" \
            || log_warn "xdg-mime: standaard bestandsbeheerder niet gezet"
    fi
}

# ---------------------------------------------------------------------------

# Dicteren met Super+H: whisper.cpp en een klein meertalig model (ongeveer
# 190 MB). Alles draait lokaal. Uit te zetten met ENABLE_DICTATION=false.
_phase11_setup_dictation() {
    if [[ "${ENABLE_DICTATION:-true}" != "true" ]]; then
        log_info "Dicteren overgeslagen (ENABLE_DICTATION=false)"
        return 0
    fi
    # Uit de repo's als dat kan (geen bouwen), anders AUR. Mislukt het, dan
    # werkt de rest gewoon en meldt Super+H dat dicteren nog niet klaar is.
    # whisper.cpp heet in extra "whisper-cpp"; het AUR-pakket whisper.cpp
    # bestaat niet meer.
    if command -v whisper-cli >/dev/null 2>&1; then
        log_ok "whisper-cli aanwezig"
    elif pacman_has_repo_pkg whisper-cpp; then
        pacman_install_optional whisper-cpp
    else
        AUR_NOCHECK=true aur_install_optional whisper.cpp-git
    fi

    local model_dir="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/whisper"
    local model="$model_dir/ggml-small-q5_1.bin"
    local url="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin"
    if [[ -s "$model" ]]; then
        log_ok "Taalmodel voor dicteren aanwezig"
    elif "${DRY_RUN:-false}"; then
        log_dry "Taalmodel zou worden gedownload naar $model"
    else
        ensure_dir "$model_dir"
        log_info "Taalmodel voor dicteren downloaden (ongeveer 190 MB)..."
        if curl -fL --retry 3 -o "$model.part" "$url"; then
            mv -f "$model.part" "$model"
            log_ok "Taalmodel geplaatst: $model"
        else
            rm -f "$model.part"
            log_warn "Taalmodel downloaden mislukt; dicteren werkt na de volgende update"
        fi
    fi
}

_phase11_optional_apps() {
    # Office-suite (ONLYOFFICE ipv LibreOffice)
    if [[ "${ENABLE_OPTIONAL_OFFICE:-false}" == "true" ]]; then
        log_info "Office-suite installeren (ENABLE_OPTIONAL_OFFICE=true)..."
        aur_install_optional onlyoffice-bin
    else
        log_info "Office-suite overgeslagen (ENABLE_OPTIONAL_OFFICE=false)"
    fi

    # Heroic Games Launcher
    if [[ "${ENABLE_OPTIONAL_HEROIC:-false}" == "true" ]]; then
        log_info "Heroic Games Launcher installeren (ENABLE_OPTIONAL_HEROIC=true)..."
        aur_install_optional heroic-games-launcher-bin
    else
        log_info "Heroic Games Launcher overgeslagen (ENABLE_OPTIONAL_HEROIC=false)"
    fi

    # VLC mediaspeler
    if [[ "${ENABLE_OPTIONAL_VLC:-false}" == "true" ]]; then
        log_info "VLC installeren (ENABLE_OPTIONAL_VLC=true)..."
        pacman_install vlc
    else
        log_info "VLC overgeslagen (ENABLE_OPTIONAL_VLC=false)"
    fi

    # Spicetify (Spotify-theming)
    if [[ "${ENABLE_SPICETIFY:-false}" == "true" ]]; then
        log_info "Spicetify installeren (ENABLE_SPICETIFY=true)..."
        aur_install_optional spicetify-cli
        _phase11_setup_spicetify
    else
        log_info "Spicetify overgeslagen (ENABLE_SPICETIFY=false)"
    fi

    # Vesktop (Discord-client met RPC + screenshare)
    if [[ "${ENABLE_VESKTOP:-false}" == "true" ]]; then
        log_info "Vesktop installeren (ENABLE_VESKTOP=true)..."
        aur_install_optional vesktop-bin
    else
        log_info "Vesktop overgeslagen (ENABLE_VESKTOP=false)"
    fi

    # VSCode — altijd nuttig maar optioneel
    if pacman -Qq visual-studio-code-bin &>/dev/null 2>&1 || \
       pacman -Qq code &>/dev/null 2>&1; then
        log_info "VSCode al geïnstalleerd — overgeslagen"
    else
        log_info "VSCode niet geïnstalleerd. Installeren via: aur_install visual-studio-code-bin"
        log_info "Of via pacman: pacman -S code (open-source build)"
    fi
}

# Logitech HID++-muizen (M720): logid laat de duimknop BTN_TASK (mouse:279)
# sturen zodat Hyprland er vensters mee kan slepen. Alleen als er een
# Logitech-apparaat (vendor 046D, USB-receiver of Bluetooth) gevonden wordt,
# of als ENABLE_LOGIOPS=true.
_phase11_setup_logiops() {
    local cfg_src="$REPO_ROOT/config/system/logid.cfg"
    local cfg_dest="/etc/logid.cfg"
    local -a logitech_devices=()

    if [[ "${ENABLE_LOGIOPS:-auto}" == "auto" ]]; then
        shopt -s nullglob
        logitech_devices=(/sys/bus/hid/devices/*:046D:*)
        shopt -u nullglob
        if (( ${#logitech_devices[@]} == 0 )); then
            log_info "Geen Logitech-apparaat gevonden — logiops overgeslagen (forceer met ENABLE_LOGIOPS=true)"
            return 0
        fi
    elif [[ "${ENABLE_LOGIOPS}" != "true" ]]; then
        log_info "logiops overgeslagen (ENABLE_LOGIOPS=${ENABLE_LOGIOPS})"
        return 0
    fi

    aur_install_optional logiops

    if "${DRY_RUN:-false}"; then
        log_dry "logid-config zou worden geplaatst: $cfg_dest (vereist sudo)"
        return 0
    fi

    if [[ ! -f "$cfg_src" ]]; then
        log_warn "Bron niet gevonden: $cfg_src"
        return 0
    fi

    if ! sudo cmp -s "$cfg_src" "$cfg_dest" 2>/dev/null; then
        backup_system_path "$cfg_dest"
        sudo install -m 0644 "$cfg_src" "$cfg_dest"
        log_ok "logid-config geplaatst: $cfg_dest"
    fi
    _phase11_install_logid_recovery
    service_enable logid
    sudo systemctl restart logid 2>/dev/null || true
    log_info "Duimknop M720:   venster slepen (mouse:279) — test met: sudo libinput debug-events"
}

# logid raakt de muis kwijt na boot, slaap of een Bluetooth-herverbinding.
# Systemd-override, udev-regel en slaap-hook laten hem dan opnieuw koppelen.
_phase11_install_logid_recovery() {
    local src="$REPO_ROOT/config/system"
    local -a pairs=(
        "logid-override.conf|/etc/systemd/system/logid.service.d/kingstra.conf|0644"
        "kingstra-logid-refresh.service|/etc/systemd/system/kingstra-logid-refresh.service|0644"
        "90-kingstra-logid.rules|/etc/udev/rules.d/90-kingstra-logid.rules|0644"
        "system-sleep-logid.sh|/usr/lib/systemd/system-sleep/kingstra-logid|0755"
    )
    local pair file dest mode

    for pair in "${pairs[@]}"; do
        IFS='|' read -r file dest mode <<< "$pair"
        if [[ ! -f "$src/$file" ]]; then
            log_warn "Bron niet gevonden: $src/$file"
            continue
        fi
        sudo cmp -s "$src/$file" "$dest" 2>/dev/null && continue
        backup_system_path "$dest"
        sudo mkdir -p "$(dirname "$dest")"
        sudo install -m "$mode" "$src/$file" "$dest"
        log_ok "logid-herstel geplaatst: $dest"
    done

    sudo systemctl daemon-reload 2>/dev/null || true
    sudo udevadm control --reload 2>/dev/null || true
    sudo systemctl reset-failed logid.service 2>/dev/null || true
}

# Losse schijven (intern of extern) koppelen bij het inloggen zonder wachtwoord,
# zodat Files ze toont. Het koppelen zelf doet kingstra-disks vanuit de sessie.
_phase11_setup_disks() {
    local script_src="$REPO_ROOT/config/shared/scripts/kingstra-disks"
    local rule_src="$REPO_ROOT/config/system/50-kingstra-udisks.rules"
    local rule_dest="/etc/polkit-1/rules.d/50-kingstra-udisks.rules"

    if "${DRY_RUN:-false}"; then
        log_dry "kingstra-disks en polkit-regel zouden worden geplaatst: $rule_dest (vereist sudo)"
        return 0
    fi

    ensure_dir "$HOME/.local/bin"
    deploy_link "$script_src" "$HOME/.local/bin/kingstra-disks"
    chmod +x "$script_src"

    if [[ ! -f "$rule_src" ]]; then
        log_warn "Bron niet gevonden: $rule_src"
        return 0
    fi
    if ! sudo cmp -s "$rule_src" "$rule_dest" 2>/dev/null; then
        backup_system_path "$rule_dest"
        sudo install -D -m 0644 "$rule_src" "$rule_dest"
        log_ok "Schijven koppelen zonder wachtwoord: $rule_dest"
    fi
}

_phase11_init_yazi_theme_file() {
    local yazi_theme="$HOME/.config/yazi/theme.toml"

    if "${DRY_RUN:-false}"; then
        log_dry "Yazi theme placeholder zou worden aangemaakt: $yazi_theme"
        return 0
    fi

    if [[ -f "$yazi_theme" || -L "$yazi_theme" ]]; then
        return 0
    fi

    cat > "$yazi_theme" <<'EOF'
# Runtime placeholder for Yazi theme.
# This file is generated/updated by Matugen integration.
EOF
    log_ok "Yazi theme placeholder aangemaakt: $yazi_theme"
}

_phase11_setup_firefox() {
    local firefox_script_src="$REPO_ROOT/config/shared/scripts/kingstra-firefox-optimize"
    local firefox_script_dest="$HOME/.local/bin/kingstra-firefox-optimize"

    if "${DRY_RUN:-false}"; then
        log_dry "Firefox profiel-optimalisaties zouden worden gedeployed"
        return 0
    fi

    deploy_config "firefox"
    ensure_dir "$HOME/.local/bin"
    deploy_link "$firefox_script_src" "$firefox_script_dest"
    chmod +x "$firefox_script_src"

    if [[ -f "$HOME/.mozilla/firefox/profiles.ini" ]] || command -v firefox >/dev/null 2>&1; then
        "$firefox_script_dest" >/dev/null 2>&1 || \
            log_warn "Firefox-profieloptimalisatie kon niet volledig worden toegepast"
    else
        log_info "Firefox-profielen nog niet gevonden — profieloptimalisatie staat klaar via kingstra-firefox-optimize"
    fi
}

_phase11_setup_spicetify() {
    if "${DRY_RUN:-false}"; then
        log_dry "Spicetify setup zou worden uitgevoerd"
        return 0
    fi

    if ! command -v spicetify &>/dev/null; then
        log_warn "spicetify niet gevonden — setup overgeslagen"
        return 0
    fi

    deploy_config "spicetify"

    mkdir -p "$HOME/.config/spicetify/Themes/Matugen"

    # Geef Spicetify schrijftoegang tot de Spotify-map
    if [[ -d /opt/spotify ]]; then
        sudo chmod a+wr /opt/spotify
        sudo chmod a+wr /opt/spotify/Apps -R
        log_ok "Spotify schrijfrechten ingesteld voor Spicetify"
    fi

    spicetify config current_theme Matugen color_scheme Matugen inject_css 1 replace_colors 1 >/dev/null 2>&1 || \
        log_warn "Spicetify config kon niet op Matugen gezet worden"

    spicetify backup apply 2>/dev/null || \
        log_warn "Spicetify backup/apply mislukt — start Spotify eerst om te initialiseren"
}

# Docker hoeft niet bij elke start mee te laden (scheelt opstarttijd en
# network-online-wachten). docker.socket start de daemon zodra iets `docker`
# gebruikt. Alleen als Docker geïnstalleerd is; niets installeren.
_phase11_docker_on_demand() {
    if ! systemctl list-unit-files docker.service 2>/dev/null | grep -q '^docker.service'; then
        log_info "Docker niet geïnstalleerd — overgeslagen"
        return 0
    fi
    if "${DRY_RUN:-false}"; then
        log_dry "docker.service zou uit de opstart gaan, docker.socket aan (vereist sudo)"
        return 0
    fi
    if [[ "$(systemctl is-enabled docker.service 2>/dev/null)" == "enabled" ]]; then
        sudo systemctl disable docker.service >/dev/null 2>&1 || log_warn "docker.service uitzetten mislukt"
    fi
    if [[ "$(systemctl is-enabled docker.socket 2>/dev/null)" != "enabled" ]]; then
        sudo systemctl enable docker.socket >/dev/null 2>&1 || log_warn "docker.socket aanzetten mislukt"
    fi
    log_ok "Docker start voortaan pas bij gebruik (docker.socket)"
}
