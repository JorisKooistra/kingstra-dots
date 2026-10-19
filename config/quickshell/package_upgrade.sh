#!/usr/bin/env bash
set -uo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
COUNT_SCRIPT="${HOME}/.config/quickshell/package_updates.sh"
AUDIT_SCRIPT="${HOME}/.config/quickshell/package_audit.sh"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra/updates"
LAST_RUN_FILE="$STATE_DIR/last-run"
NEWS_URL="https://archlinux.org/feeds/news/"
LOG_KEEP=10
overall_exit=0
DOTFILES_REPO=""
LOG_FILE=""

section() {
    printf '\n%s\n' "──────────────────────────────────────────────"
    printf '%s\n' "$1"
    printf '%s\n\n' "──────────────────────────────────────────────"
}

# Het log bevat de samenvatting van elke run, niet de volledige yay-uitvoer:
# die door tee halen zou pacman zijn tty en voortgangsbalken afnemen.
init_log() {
    mkdir -p "$STATE_DIR" 2>/dev/null || return 0
    LOG_FILE="$STATE_DIR/update-$(date +%Y%m%d-%H%M%S).log"
    : > "$LOG_FILE" 2>/dev/null || LOG_FILE=""

    local old
    while IFS= read -r old; do
        rm -f -- "$old"
    done < <(find "$STATE_DIR" -maxdepth 1 -name 'update-*.log' -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | tail -n +$((LOG_KEEP + 1)) | cut -d' ' -f2-)
}

log() {
    printf '%s\n' "$*"
    [[ -n "$LOG_FILE" ]] && printf '%s\n' "$*" >> "$LOG_FILE"
    return 0
}

log_block() {
    local text="$1"
    [[ -n "$text" ]] || return 0
    printf '%s\n' "$text"
    [[ -n "$LOG_FILE" ]] && printf '%s\n' "$text" >> "$LOG_FILE"
    return 0
}

# Ja/nee-vragen. Zonder terminal (of bij EOF) geldt het standaardantwoord,
# zodat het script nooit blijft hangen en niets ongevraagd verwijdert.
ask_no() {
    local reply=""
    read -r -p "$1 [j/N] " reply || return 1
    [[ "$reply" =~ ^[jJyY] ]]
}

ask_yes() {
    local reply=""
    read -r -p "$1 [J/n] " reply || return 0
    [[ ! "$reply" =~ ^[nN] ]]
}

preview_updates() {
    local repo_list="" aur_list="" flatpak_list="" helper=""

    if command -v checkupdates >/dev/null 2>&1; then
        repo_list="$(timeout 90 checkupdates 2>/dev/null || true)"
    fi
    if command -v yay >/dev/null 2>&1; then
        helper="yay"
    elif command -v paru >/dev/null 2>&1; then
        helper="paru"
    fi
    if [[ -n "$helper" ]]; then
        aur_list="$(timeout 90 "$helper" -Qua 2>/dev/null || true)"
    fi
    if command -v flatpak >/dev/null 2>&1; then
        flatpak_list="$(timeout 90 flatpak remote-ls --updates --columns=application,version 2>/dev/null || true)"
    fi

    if [[ -z "$repo_list$aur_list$flatpak_list" ]]; then
        log "Geen pakket- of Flatpak-updates gevonden (of de check kon niet draaien)."
        return 0
    fi
    if [[ -n "$repo_list" ]]; then
        log "Arch ($(printf '%s\n' "$repo_list" | grep -c .)):"
        log_block "$(printf '%s\n' "$repo_list" | sed 's/^/  /')"
    fi
    if [[ -n "$aur_list" ]]; then
        log "AUR ($(printf '%s\n' "$aur_list" | grep -c .)):"
        log_block "$(printf '%s\n' "$aur_list" | sed 's/^/  /')"
    fi
    if [[ -n "$flatpak_list" ]]; then
        log "Flatpak ($(printf '%s\n' "$flatpak_list" | grep -c .)):"
        log_block "$(printf '%s\n' "$flatpak_list" | sed 's/^/  /')"
    fi
    if printf '%s\n' "$repo_list" | grep -qE '^linux(-lts|-zen|-hardened)? '; then
        log "Let op: er zit een kernel-update bij; na afloop is een herstart nodig."
    fi
}

# Toont Arch-nieuws sinds de vorige run (eerste keer: de drie nieuwste).
# Nieuws vraagt soms handwerk vóór een update, dus bij nieuwe berichten wacht
# het script op een bevestiging.
check_arch_news() {
    local feed="" last_run=0 shown=0 title="" pub="" ts=0 latest=""

    command -v curl >/dev/null 2>&1 || {
        log "curl ontbreekt; Arch-nieuws overgeslagen."
        return 0
    }
    feed="$(curl -fsSL --max-time 8 "$NEWS_URL" 2>/dev/null || true)"
    if [[ -z "$feed" ]]; then
        log "Arch-nieuws kon niet worden opgehaald; overgeslagen."
        return 0
    fi

    [[ -f "$LAST_RUN_FILE" ]] && read -r last_run < "$LAST_RUN_FILE"
    [[ "$last_run" =~ ^[0-9]+$ ]] || last_run=0

    while IFS=$'\t' read -r title pub; do
        [[ -n "$title" ]] || continue
        [[ -n "$latest" ]] || latest="$(date -d "$pub" +%Y-%m-%d 2>/dev/null || echo '?')  $title"
        ts="$(date -d "$pub" +%s 2>/dev/null || echo 0)"
        if [[ "$last_run" -eq 0 && "$shown" -ge 3 ]] || [[ "$last_run" -gt 0 && "$ts" -le "$last_run" ]]; then
            break
        fi
        log "  $(date -d "$pub" +%Y-%m-%d 2>/dev/null || echo '?')  $title"
        shown=$((shown + 1))
    done < <(printf '%s' "$feed" | tr -d '\n' | sed 's/<item>/\n/g' | tail -n +2 \
        | sed -nE 's|.*<title>([^<]*)</title>.*<pubDate>([^<]*)</pubDate>.*|\1\t\2|p' \
        | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;/'"'"'/g')

    if [[ "$shown" -eq 0 ]]; then
        log "Geen nieuw Arch-nieuws sinds de vorige update."
        [[ -n "$latest" ]] && log "Laatste bericht: $latest"
        return 0
    fi
    log "Lees ze op https://archlinux.org/news/ als er handwerk bij staat."
    if ! ask_yes "Doorgaan met updaten?"; then
        log "Update op verzoek gestopt na het nieuws."
        return 1
    fi
}

report_pacnew() {
    local files=""
    command -v pacman >/dev/null 2>&1 || return 0
    files="$(find /etc -xdev \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null | sort)"
    if [[ -z "$files" ]]; then
        log "Geen .pacnew- of .pacsave-bestanden in /etc."
        return 0
    fi
    log "Deze configbestanden wachten op een vergelijking (sudo pacdiff):"
    log_block "$(printf '%s\n' "$files" | sed 's/^/  /')"
}

report_reboot() {
    command -v pacman >/dev/null 2>&1 || return 0
    if [[ -d "/usr/lib/modules/$(uname -r)" ]]; then
        log "Geen herstart nodig; de draaiende kernel is nog geïnstalleerd."
    else
        log "Herstart nodig: de draaiende kernel $(uname -r) is vervangen."
    fi
}

cleanup_system() {
    local orphans=""

    if command -v pacman >/dev/null 2>&1; then
        orphans="$(pacman -Qdtq 2>/dev/null || true)"
        if [[ -n "$orphans" ]]; then
            log "Verweesde pakketten ($(printf '%s\n' "$orphans" | grep -c .)):"
            log_block "$(printf '%s\n' "$orphans" | sed 's/^/  /')"
            if ask_no "Deze pakketten verwijderen?"; then
                # shellcheck disable=SC2086
                sudo pacman -Rns -- $orphans && log "Verweesde pakketten verwijderd."
            else
                log "Verweesde pakketten blijven staan."
            fi
        else
            log "Geen verweesde pakketten."
        fi
    fi

    if command -v paccache >/dev/null 2>&1; then
        if ask_no "Oude pakketcache opruimen (houdt de laatste 2 versies)?"; then
            sudo paccache -rk2 && sudo paccache -ruk0 && log "Pakketcache opgeruimd."
        fi
    fi

    if command -v flatpak >/dev/null 2>&1; then
        if ask_no "Ongebruikte Flatpak-runtimes verwijderen?"; then
            flatpak uninstall --unused -y && log "Ongebruikte Flatpak-runtimes verwijderd."
        fi
    fi

    # Elk extra pakket brengt zijn eigen updates mee; laat zien wat er
    # waarschijnlijk weg kan. Verwijderen gebeurt alleen per pakket na "j".
    if [[ -x "$AUDIT_SCRIPT" ]]; then
        log_block "$("$AUDIT_SCRIPT" --summary 2>/dev/null || true)"
        if ask_no "Kandidaten nu een voor een bekijken?"; then
            "$AUDIT_SCRIPT" --review
        else
            log "Later bekijken: $AUDIT_SCRIPT"
        fi
    fi
}

resolve_dotfiles_repo() {
    local marker="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/install-complete"
    local repo=""
    local script_path=""

    if [[ -f "$marker" ]]; then
        repo="$(sed -n 's/^Repo:[[:space:]]*//p' "$marker" | head -n 1)"
    fi
    if [[ -z "$repo" ]]; then
        script_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || true)"
        if [[ -n "$script_path" ]]; then
            repo="$(cd "$(dirname "$script_path")/../.." 2>/dev/null && pwd -P || true)"
        fi
    fi

    [[ -n "$repo" && -d "$repo/.git" ]] || return 1
    printf '%s\n' "$repo"
}

update_dotfiles() {
    local repo=""
    local branch=""
    local upstream=""
    local behind=0
    local ahead=0

    repo="$(resolve_dotfiles_repo 2>/dev/null || true)"
    if [[ -z "$repo" ]]; then
        echo "Geen geïnstalleerde kingstra-dots git-repo gevonden; overgeslagen."
        return 0
    fi
    DOTFILES_REPO="$repo"

    branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [[ -z "$branch" ]]; then
        echo "Dotfiles-repo staat niet op een branch; overgeslagen."
        return 0
    fi

    if ! git -C "$repo" fetch --quiet origin "$branch"; then
        echo "Dotfiles ophalen mislukt."
        return 1
    fi

    upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    if [[ -z "$upstream" ]] && git -C "$repo" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
        upstream="origin/$branch"
    fi
    if [[ -z "$upstream" ]]; then
        echo "Geen upstream voor branch '$branch'; overgeslagen."
        return 0
    fi

    behind="$(git -C "$repo" rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
    ahead="$(git -C "$repo" rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)"
    if [[ "$behind" -eq 0 ]]; then
        echo "Dotfiles zijn al actueel."
        return 0
    fi

    # Alleen gewijzigde bestanden die git bijhoudt blokkeren de update. Losse
    # nieuwe bestanden (zoals een eigen keep-lijst) kunnen gewoon blijven
    # staan: merge --ff-only weigert zelf als zo'n bestand overschreven zou
    # worden, dus er gaat niets verloren.
    if [[ -n "$(git -C "$repo" status --porcelain --untracked-files=no)" ]]; then
        echo "Er staan lokale wijzigingen in $repo:"
        git -C "$repo" status --short --untracked-files=no
        echo "Dotfiles-update veilig overgeslagen; commit of stash ze eerst."
        return 0
    fi
    if [[ "$ahead" -gt 0 ]]; then
        echo "De lokale branch loopt ook $ahead commit(s) voor op upstream."
        echo "Automatisch samenvoegen is overgeslagen."
        return 0
    fi

    echo "$behind nieuwe dotfiles-commit(s) gevonden."
    if ! git -C "$repo" merge --ff-only "$upstream"; then
        echo "Bijwerken mislukt; waarschijnlijk staat er een los bestand in de weg (zie hierboven)."
        return 1
    fi
}

run_dotfiles_installer() {
    local repo="$1"
    local installer="$repo/install.sh"

    if [[ ! -f "$installer" ]]; then
        echo "Installer niet gevonden: $installer"
        return 1
    fi

    echo "Kingstra installer uitvoeren voor pakketten, gegenereerde config en live reload..."
    bash "$installer" --yes
}

init_log

echo "=============================================="
echo " Kingstra Update Runner"
echo " yay · Flatpak · kingstra-dots"
echo "=============================================="
log "Gestart: $(date '+%Y-%m-%d %H:%M:%S')"

section "Arch-nieuws"
if ! check_arch_news; then
    [[ -n "$LOG_FILE" ]] && echo "Log: $LOG_FILE"
    read -r -p "Druk Enter om te sluiten..." _
    exit 0
fi

section "Wat er bijwerkt"
preview_updates

section "Arch/AUR"
arch_exit=0
if command -v yay >/dev/null 2>&1; then
    yay -Syu || arch_exit=$?
elif command -v paru >/dev/null 2>&1; then
    paru -Syu || arch_exit=$?
else
    log "Geen yay of paru gevonden; Arch/AUR-update overgeslagen."
fi
[[ $arch_exit -eq 0 ]] || overall_exit=$arch_exit
log "Arch/AUR: exitcode $arch_exit"

section "Flatpak"
flatpak_exit=0
if command -v flatpak >/dev/null 2>&1; then
    flatpak update || flatpak_exit=$?
else
    log "Flatpak is niet geïnstalleerd; overgeslagen."
fi
[[ $flatpak_exit -eq 0 ]] || overall_exit=$flatpak_exit
log "Flatpak: exitcode $flatpak_exit"

section "Dotfiles"
dotfiles_update_exit=0
update_dotfiles || dotfiles_update_exit=$?

# Een git pull alleen is niet genoeg: nieuwe pakketten, gegenereerde hardware-
# config en live sessiewijzigingen worden pas door install.sh toegepast. Draai
# de installer ook als de repo al actueel is, zodat een eerdere half-afgeronde
# update zichzelf kan herstellen.
if [[ -n "$DOTFILES_REPO" ]]; then
    if ! run_dotfiles_installer "$DOTFILES_REPO"; then
        overall_exit=1
    fi
fi

if [[ $dotfiles_update_exit -ne 0 ]]; then
    overall_exit=1
fi

log "Dotfiles: exitcode $dotfiles_update_exit"

section "Na de update"
report_pacnew
report_reboot

section "Opruimen"
cleanup_system

if [[ $arch_exit -eq 0 ]]; then
    mkdir -p "$STATE_DIR" 2>/dev/null && date +%s > "$LAST_RUN_FILE"
fi

mkdir -p "$CACHE_DIR"
rm -f "$CACHE_DIR/package_updates_status" "$CACHE_DIR/package_updates_count"
"$COUNT_SCRIPT" --refresh >/dev/null 2>&1 || true

section "Klaar"
if [[ $overall_exit -eq 0 ]]; then
    log "Alle beschikbare updatebronnen zijn verwerkt."
else
    log "Minstens één updatebron eindigde met een fout (code $overall_exit)."
fi
[[ -n "$LOG_FILE" ]] && echo "Log: $LOG_FILE"
echo
read -r -p "Druk Enter om te sluiten..." _
exit "$overall_exit"
