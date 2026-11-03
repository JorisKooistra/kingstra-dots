#!/usr/bin/env bash
# =============================================================================
# Fase 14b — Vangnet: terugdraaien, back-ups, schijfgezondheid, opstartbeeld
# =============================================================================
# Doel (keuzes uit de vergelijkronde "betrouwbaarheid en onderhoud"):
#   - kingstra-health/-herstel/-backup/-plymouth-sync in ~/.local/bin
#   - etckeeper: elke wijziging in /etc wordt vastgelegd
#   - reflector: mirrorlijst wekelijks ververst
#   - smartd: alle schijven bewaakt, melding bij slijtage
#   - updates dagelijks alvast downloaden (checkupdates -d, installeert niets)
#   - kernel-modules-hook: USB en geluid blijven werken tot je herstart
#   - systemd-boot: Kingstra / Kingstra (veilig) / Kingstra herstel, met
#     automatisch terugvallen op de LTS-kernel na drie mislukte starts
#   - Plymouth-opstartbeeld in themakleuren, naadloos naar het inlogscherm
#   - back-up van ~ naar een datadisk (restic), tweede kopie wekelijks
# Alles is idempotent en slaat stil over wat op deze pc niet past.
# =============================================================================

VANGNET_SRC="$REPO_ROOT/config/system/vangnet"
VANGNET_LIB="/usr/local/lib/kingstra"

phase_run() {
    log_step "Vangnet-pakketten installeren..."
    # Eén voor één en niet onmisbaar: een ontbrekend pakket slaat alleen dat
    # onderdeel over, niet de hele update.
    local pkg
    for pkg in restic fuse3 rsync smartmontools etckeeper reflector \
        kernel-modules-hook plymouth python-pillow pacman-contrib; do
        pacman_install_optional "$pkg"
    done

    log_step "Vangnet-commando's plaatsen..."
    _phase14b_deploy_scripts

    if "${DRY_RUN:-false}"; then
        log_dry "Systeeminstellingen voor het vangnet zouden worden gezet (sudo)"
        return 0
    fi

    log_step "Systeeminstellingen bijhouden (etckeeper)..."
    _phase14b_etckeeper

    log_step "Mirrorlijst automatisch verversen (reflector)..."
    _phase14b_reflector

    log_step "Schijfgezondheid bewaken (smartd)..."
    _phase14b_smartd

    log_step "Updates alvast downloaden..."
    _phase14b_prefetch

    log_step "Kernelmodules bewaren tot herstart..."
    _phase14b_enable_system linux-modules-cleanup.service

    log_step "Opstartmenu met automatisch terugvallen..."
    _phase14b_boot_entries

    log_step "Opstartbeeld (Plymouth)..."
    _phase14b_plymouth

    log_step "Back-ups instellen..."
    _phase14b_backup

    log_step "Gezondheidscheck..."
    _phase14b_user_timer kingstra-health

    validate_cmd restic
    validate_cmd smartctl
    validate_file "$HOME/.local/bin/kingstra-health" "kingstra-health"
    validate_file "$HOME/.local/bin/kingstra-backup" "kingstra-backup"
    validate_report
    log_ok "Fase 14b voltooid — vangnet staat."
}

# ---------------------------------------------------------------------------

_phase14b_deploy_scripts() {
    local scripts_dir="$REPO_ROOT/config/shared/scripts" name
    if "${DRY_RUN:-false}"; then
        log_dry "kingstra-health, -herstel, -backup, -plymouth-sync, -aur-cache en -pacnew-merge zouden in ~/.local/bin komen"
        return 0
    fi
    ensure_dir "$HOME/.local/bin"
    for name in kingstra-health kingstra-herstel kingstra-backup kingstra-plymouth-sync kingstra-aur-cache kingstra-pacnew-merge; do
        chmod +x "$scripts_dir/$name"
        deploy_link "$scripts_dir/$name" "$HOME/.local/bin/$name"
    done
}

# Systeembestand plaatsen als het anders is; eerst een back-up.
_phase14b_install() {
    local mode="$1" src="$2" dest="$3"
    if sudo cmp -s "$src" "$dest" 2>/dev/null; then
        return 1
    fi
    backup_system_path "$dest"
    sudo install -D -m "$mode" "$src" "$dest"
    return 0
}

_phase14b_enable_system() {
    local unit="$1"
    systemctl list-unit-files "$unit" >/dev/null 2>&1 || { log_warn "$unit niet gevonden"; return 0; }
    if [[ "$(systemctl is-enabled "$unit" 2>/dev/null)" != "enabled" ]]; then
        sudo systemctl enable --now "$unit" >/dev/null 2>&1 || log_warn "$unit aanzetten mislukt"
    fi
}

_phase14b_etckeeper() {
    command -v etckeeper >/dev/null 2>&1 || { log_warn "etckeeper ontbreekt"; return 0; }
    if ! sudo test -d /etc/.git; then
        sudo etckeeper init >/dev/null 2>&1 || { log_warn "etckeeper init mislukt"; return 0; }
        sudo git -C /etc config user.name "kingstra"
        sudo git -C /etc config user.email "root@localhost"
        sudo etckeeper commit "Kingstra: begin van de geschiedenis van /etc" >/dev/null 2>&1 || true
        log_ok "/etc wordt voortaan bijgehouden (sudo git -C /etc log)"
    fi
    # De pacman-hooks van etckeeper doen de rest; een dagelijkse vangst voor
    # wijzigingen buiten pacman om.
    _phase14b_enable_system etckeeper.timer
}

_phase14b_reflector() {
    local conf="/etc/xdg/reflector/reflector.conf" tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<'EOF'
# Kingstra: snelle, recente https-mirrors dicht bij huis. reflector.timer
# ververst /etc/pacman.d/mirrorlist wekelijks.
--save /etc/pacman.d/mirrorlist
--protocol https
--country Netherlands,Belgium,Germany
--latest 15
--age 12
--sort rate
EOF
    if _phase14b_install 0644 "$tmp" "$conf"; then
        log_ok "reflector ingesteld: $conf"
    fi
    rm -f "$tmp"
    _phase14b_enable_system reflector.timer
}

_phase14b_smartd() {
    command -v smartd >/dev/null 2>&1 || { log_warn "smartmontools ontbreekt"; return 0; }
    _phase14b_install 0755 "$VANGNET_SRC/smartd-notify.sh" "$VANGNET_LIB/smartd-notify" || true
    if _phase14b_install 0644 "$VANGNET_SRC/smartd.conf" /etc/smartd.conf; then
        sudo systemctl restart smartd.service >/dev/null 2>&1 || true
    fi
    sudo install -d -m 0755 /var/lib/kingstra
    _phase14b_enable_system smartd.service
}

_phase14b_prefetch() {
    local changed=false unit
    for unit in kingstra-update-prefetch.service kingstra-update-prefetch.timer; do
        _phase14b_install 0644 "$VANGNET_SRC/$unit" "/etc/systemd/system/$unit" && changed=true
    done
    $changed && sudo systemctl daemon-reload
    _phase14b_enable_system kingstra-update-prefetch.timer
}

# Alleen met systemd-boot; GRUB of Limine laten we met rust.
_phase14b_boot_entries() {
    if ! command -v bootctl >/dev/null 2>&1 || ! sudo bootctl is-installed >/dev/null 2>&1 \
        || ! sudo test -d /boot/loader/entries; then
        log_info "Geen systemd-boot gevonden; opstartmenu overgeslagen."
        return 0
    fi
    _phase14b_install 0755 "$VANGNET_SRC/kingstra-boot-entries" "$VANGNET_LIB/kingstra-boot-entries" || true
    _phase14b_install 0644 "$VANGNET_SRC/95-kingstra-boot-count.hook" /etc/pacman.d/hooks/95-kingstra-boot-count.hook || true
    if _phase14b_install 0644 "$VANGNET_SRC/kingstra-boot-ok.service" /etc/systemd/system/kingstra-boot-ok.service; then
        sudo systemctl daemon-reload
    fi
    sudo systemctl enable kingstra-boot-ok.service >/dev/null 2>&1 || log_warn "kingstra-boot-ok.service aanzetten mislukt"
    local out
    if out="$(sudo /usr/bin/python3 -I "$VANGNET_LIB/kingstra-boot-entries" setup 2>&1)"; then
        log_ok "$out"
        log_info "Opstartmenu: houd spatie ingedrukt bij het aanzetten."
    else
        log_warn "Opstartmenu instellen mislukt: $out"
    fi
}

_phase14b_plymouth() {
    command -v plymouth-set-default-theme >/dev/null 2>&1 || { log_warn "plymouth ontbreekt"; return 0; }
    if python3 "$REPO_ROOT/config/shared/scripts/kingstra-plymouth-sync" --install >/dev/null 2>&1; then
        log_ok "Opstartbeeld in themakleuren ingesteld"
    else
        log_warn "Opstartbeeld instellen mislukt"
        return 0
    fi
    if _phase14b_install 0644 "$VANGNET_SRC/sddm-plymouth.conf" /etc/systemd/system/sddm.service.d/kingstra-plymouth.conf; then
        sudo systemctl daemon-reload
        log_ok "Opstartbeeld blijft staan tot het inlogscherm er is"
    fi
}

# Schrijft backup.conf één keer, met de schijven die op deze pc gekoppeld zijn.
_phase14b_backup() {
    local conf="$HOME/.config/kingstra/backup.conf" repo="" copy="" disk
    if [[ ! -f "$conf" ]]; then
        for disk in /mnt/data2 /mnt/data3 /mnt/data1; do
            if mountpoint -q "$disk" 2>/dev/null; then
                if [[ -z "$repo" ]]; then repo="$disk/Kingstra-backup"
                elif [[ -z "$copy" ]]; then copy="$disk/Kingstra-backup"; fi
            fi
        done
        ensure_dir "$(dirname "$conf")"
        {
            echo "# Kingstra back-up (kingstra-backup). Aangemaakt door de installer; pas gerust aan."
            if [[ -n "$repo" ]]; then echo "BACKUP_ENABLED=true"; else echo "BACKUP_ENABLED=false"; fi
            echo "BACKUP_REPO=\"${repo:-/mnt/data2/Kingstra-backup}\""
            echo "BACKUP_COPY=\"$copy\""
            if [[ -d "/mnt/data1/backup windows" && "$copy" == /mnt/data3/* ]]; then
                echo 'BACKUP_MIRROR_SRC="/mnt/data1/backup windows"'
                echo 'BACKUP_MIRROR_DEST="/mnt/data3/backup windows"'
            else
                echo 'BACKUP_MIRROR_SRC=""'
                echo 'BACKUP_MIRROR_DEST=""'
            fi
            echo "# Extra uitzonderingen: ~/.config/kingstra/backup-exclude.local.txt"
        } > "$conf"
        log_ok "Back-upinstellingen: $conf"
    fi

    BACKUP_ENABLED=false BACKUP_REPO="" BACKUP_COPY="" BACKUP_MIRROR_DEST=""
    # shellcheck disable=SC1090
    source "$conf"
    if [[ "${BACKUP_ENABLED:-false}" != "true" ]]; then
        log_info "Geen datadisk gevonden; back-up staat uit (zet aan in $conf)."
    else
        local dir
        for dir in "$BACKUP_REPO" "$BACKUP_COPY" "$BACKUP_MIRROR_DEST"; do
            [[ -n "$dir" ]] || continue
            mountpoint -q "$(dirname "$dir")" 2>/dev/null || continue
            if [[ ! -d "$dir" ]]; then
                sudo install -d -o "$(id -u)" -g "$(id -g)" -m 0750 "$dir"
            elif [[ ! -w "$dir" ]]; then
                sudo chown "$(id -u):$(id -g)" "$dir"
            fi
        done
        log_ok "Back-up naar $BACKUP_REPO${BACKUP_COPY:+, kopie naar $BACKUP_COPY}"
    fi
    _phase14b_user_timer kingstra-backup
    _phase14b_user_timer kingstra-backup-copy
}

_phase14b_user_timer() {
    local name="$1" dest="$HOME/.config/systemd/user"
    ensure_dir "$dest"
    deploy_link "$REPO_ROOT/config/systemd/$name.service" "$dest/$name.service"
    deploy_link "$REPO_ROOT/config/systemd/$name.timer" "$dest/$name.timer"
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now "$name.timer" >/dev/null 2>&1 || log_warn "$name.timer aanzetten mislukt"
}
