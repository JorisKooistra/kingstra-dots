#!/usr/bin/env bash
# Kingstra Update Runner: Arch-nieuws, Arch/AUR, Flatpak en dotfiles in één run.
# In een terminal toont het per stap een korte samenvatting en een
# voortgangsbalk; de volledige uitvoer van yay/flatpak gaat naar het log.
# --interactief geeft yay en flatpak weer hun eigen uitvoer en vragen.
set -uo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
COUNT_SCRIPT="${HOME}/.config/quickshell/package_updates.sh"
AUDIT_SCRIPT="${HOME}/.config/quickshell/package_audit.sh"
SNAPSHOT_CMD="${KINGSTRA_SNAPSHOT_CMD:-$HOME/.local/bin/kingstra-snapshot}"
HOLD_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra/update-hold"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra/updates"
LAST_RUN_FILE="$STATE_DIR/last-run"
NEWS_URL="https://archlinux.org/feeds/news/"
LOG_KEEP=10
overall_exit=0
DOTFILES_REPO=""
LOG_FILE=""

# Pakketten die bij een update het vermelden waard zijn.
NOTABLE_RE='^(linux(-lts|-zen|-hardened)?|linux-firmware|nvidia[^ ]*|mesa|vulkan-[^ ]+|systemd|glibc|hyprland|hyprlock|hypridle|quickshell[^ ]*|pipewire|wireplumber|sddm|networkmanager|bluez|grub|mkinitcpio) '
INLINE_MAX=6

INTERACTIVE=false
[[ "${1:-}" == "--interactief" || "${1:-}" == "--interactive" ]] && INTERACTIVE=true

# ---------------------------------------------------------------------------
# Weergave
# ---------------------------------------------------------------------------
UI=false
[[ -t 0 && -t 1 && "${TERM:-}" != "dumb" ]] && UI=true

STEPS_TOTAL=8
STEP_NUM=0
STEP_TITLE=""
SUMMARY=()
LIVE_SHOWN=false
SPIN_IDX=0

C_RESET="" C_BOLD="" C_DIM="" C_GREEN="" C_YELLOW="" C_RED="" C_CYAN=""
G_OK="OK" G_WARN="!" G_FAIL="X" G_DOT="-" G_ASK="?" BAR_FULL="#" BAR_EMPTY="-"
SPIN=('-' '\' '|' '/')
if $UI; then
    C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
    C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_RED=$'\033[31m' C_CYAN=$'\033[36m'
    if [[ "$(locale charmap 2>/dev/null)" == "UTF-8" || "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" =~ [Uu][Tt][Ff]-?8 ]]; then
        G_OK="✓" G_WARN="!" G_FAIL="✗" G_DOT="·" G_ASK="?" BAR_FULL="█" BAR_EMPTY="░"
        SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    fi
fi

bar() {
    local total="$1" current="$2" width="${3:-24}" filled=0 i out=""
    (( total > 0 )) && filled=$((current * width / total))
    (( filled > width )) && filled=$width
    for (( i = 0; i < width; i++ )); do
        if (( i < filled )); then out+="$BAR_FULL"; else out+="$BAR_EMPTY"; fi
    done
    printf '%s' "$out"
}

term_cols() {
    local cols
    cols="$(tput cols 2>/dev/null || true)"
    [[ "$cols" =~ ^[0-9]+$ ]] || cols="${COLUMNS:-80}"
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
    printf '%s' "$cols"
}

# Eén regel die steeds overschreven wordt: spinner, optionele balk, tekst.
live() {
    $UI || return 0
    local msg="$1" done="${2:-}" total="${3:-}" prefix plain max
    local spin="${SPIN[SPIN_IDX % ${#SPIN[@]}]}"
    SPIN_IDX=$((SPIN_IDX + 1))
    if [[ -n "$total" && "$total" -gt 0 ]]; then
        plain="    $spin $(bar "$total" "$done" 20) $done/$total  "
        prefix="    ${C_CYAN}${spin}${C_RESET} ${C_GREEN}$(bar "$total" "$done" 20)${C_RESET} ${C_BOLD}${done}/${total}${C_RESET}  "
    else
        plain="    $spin "
        prefix="    ${C_CYAN}${spin}${C_RESET} "
    fi
    max=$(( $(term_cols) - ${#plain} - 1 ))
    (( max < 10 )) && max=10
    (( ${#msg} > max )) && msg="${msg:0:$((max - 1))}…"
    printf '\033[?25l\r\033[K%s%s%s%s' "$prefix" "$C_DIM" "$msg" "$C_RESET"
    LIVE_SHOWN=true
}

live_clear() {
    $UI || return 0
    if $LIVE_SHOWN; then
        printf '\r\033[K'
        LIVE_SHOWN=false
    fi
    printf '\033[?25h'
}
trap 'live_clear' EXIT

to_log() {
    [[ -n "$LOG_FILE" ]] && printf '%s\n' "$@" >> "$LOG_FILE"
    return 0
}

section() {
    STEP_NUM=$((STEP_NUM + 1))
    STEP_TITLE="$1"
    to_log "" "== $1 =="
    if $UI; then
        live_clear
        printf '\n  %s%s%s %s%d/%d%s  %s%s%s\n' \
            "$C_GREEN" "$(bar "$STEPS_TOTAL" "$((STEP_NUM - 1))" 14)" "$C_RESET" \
            "$C_DIM" "$STEP_NUM" "$STEPS_TOTAL" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"
        return 0
    fi
    printf '\n%s\n' "──────────────────────────────────────────────"
    printf '%s\n' "$1"
    printf '%s\n\n' "──────────────────────────────────────────────"
}

# Het resultaat van een stap; komt ook terug in de eindsamenvatting.
result() {
    local kind="$1" msg="$2" glyph color
    case "$kind" in
        ok) glyph="$G_OK"; color="$C_GREEN" ;;
        warn) glyph="$G_WARN"; color="$C_YELLOW" ;;
        *) glyph="$G_FAIL"; color="$C_RED" ;;
    esac
    SUMMARY+=("$kind|$STEP_TITLE|$msg")
    to_log "[$kind] $msg"
    if $UI; then
        live_clear
        printf '    %s%s%s %s\n' "$color" "$glyph" "$C_RESET" "$msg"
    else
        printf '%s\n' "$msg"
    fi
}

log() {
    if $UI; then
        live_clear
        printf '    %s\n' "$*"
    else
        printf '%s\n' "$*"
    fi
    to_log "$*"
}

log_block() {
    local text="$1"
    [[ -n "$text" ]] || return 0
    if $UI; then
        live_clear
        printf '%s\n' "$text" | sed 's/^/    /'
    else
        printf '%s\n' "$text"
    fi
    to_log "$text"
}

# Toont hoogstens INLINE_MAX namen op één regel; de rest staat in het log.
inline_names() {
    local -a names=()
    mapfile -t names < <(printf '%s\n' "$1" | awk 'NF { print $1 }')
    local n=${#names[@]} shown="${names[*]:0:$INLINE_MAX}"
    shown="${shown// /, }"
    (( n > INLINE_MAX )) && shown+=" en nog $((n - INLINE_MAX))"
    printf '%s' "$shown"
}

count_lines() {
    [[ -n "$1" ]] || { printf '0'; return; }
    printf '%s\n' "$1" | grep -c .
}

# Het log bevat de samenvatting van elke run plus de volledige uitvoer van
# de stappen die stil (met voortgangsbalk) draaien.
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

# Draait een commando stil: uitvoer naar het log, in de terminal een
# voortgangsregel. Tellers als "( 3/87) upgrading foo" van pacman worden
# een balk; anders staat de laatste uitvoerregel achter de spinner.
run_quiet() {
    local label="$1"
    shift
    local tmp rc=0 last="" counter="" done="" total="" text=""
    tmp="$(mktemp)"
    to_log "\$ $*"
    "$@" </dev/null >"$tmp" 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        last="$(tail -n 30 "$tmp" 2>/dev/null | tr '\r' '\n' | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | awk 'NF' | tail -n 1)"
        counter="$(tail -n 60 "$tmp" 2>/dev/null | tr '\r' '\n' | grep -E '^\( *[0-9]+/[0-9]+\) ' | tail -n 1)"
        done="" total=""
        if [[ "$counter" =~ ^\(\ *([0-9]+)/([0-9]+)\)\ +(.*)$ ]]; then
            done="${BASH_REMATCH[1]}" total="${BASH_REMATCH[2]}" text="${BASH_REMATCH[3]}"
            live "$label: $text" "$done" "$total"
        else
            live "$label${last:+: $last}"
        fi
        sleep 0.15
    done
    wait "$pid" || rc=$?
    [[ -n "$LOG_FILE" ]] && cat "$tmp" >> "$LOG_FILE"
    live_clear
    if (( rc != 0 )); then
        printf '    %sLaatste uitvoer:%s\n' "$C_DIM" "$C_RESET"
        tr '\r' '\n' < "$tmp" | awk 'NF' | tail -n 8 | sed 's/^/      /'
    fi
    rm -f "$tmp"
    return "$rc"
}

# Ja/nee-vragen. Zonder terminal (of bij EOF) geldt het standaardantwoord,
# zodat het script nooit blijft hangen en niets ongevraagd verwijdert.
ask_no() {
    local reply=""
    live_clear
    if $UI; then
        read -r -p "    ${C_CYAN}${G_ASK}${C_RESET} $1 ${C_DIM}[j/N]${C_RESET} " reply || return 1
    else
        read -r -p "$1 [j/N] " reply || return 1
    fi
    [[ "$reply" =~ ^[jJyY] ]]
}

ask_yes() {
    local reply=""
    live_clear
    if $UI; then
        read -r -p "    ${C_CYAN}${G_ASK}${C_RESET} $1 ${C_DIM}[J/n]${C_RESET} " reply || return 0
    else
        read -r -p "$1 [J/n] " reply || return 0
    fi
    [[ ! "$reply" =~ ^[nN] ]]
}

REPO_COUNT=0
AUR_COUNT=0
FLATPAK_COUNT=0

# Korte samenvatting per bron; de volledige lijsten gaan naar het log.
preview_updates() {
    local repo_list="" aur_list="" flatpak_list="" helper="" notable=""

    live "Updates zoeken"
    if command -v checkupdates >/dev/null 2>&1; then
        repo_list="$(timeout 90 checkupdates 2>/dev/null || true)"
    fi
    if command -v yay >/dev/null 2>&1; then
        helper="yay"
    elif command -v paru >/dev/null 2>&1; then
        helper="paru"
    fi
    if [[ -n "$helper" ]]; then
        live "AUR-updates zoeken"
        aur_list="$(timeout 90 "$helper" -Qua 2>/dev/null || true)"
    fi
    if command -v flatpak >/dev/null 2>&1; then
        live "Flatpak-updates zoeken"
        flatpak_list="$(timeout 90 flatpak remote-ls --updates --columns=application,version 2>/dev/null || true)"
    fi
    live_clear

    REPO_COUNT="$(count_lines "$repo_list")"
    AUR_COUNT="$(count_lines "$aur_list")"
    FLATPAK_COUNT="$(count_lines "$flatpak_list")"

    if [[ -z "$repo_list$aur_list$flatpak_list" ]]; then
        log "Geen pakket- of Flatpak-updates gevonden (of de check kon niet draaien)."
        return 0
    fi

    to_log "-- Arch ($REPO_COUNT) --" "$repo_list" "-- AUR ($AUR_COUNT) --" "$aur_list" \
        "-- Flatpak ($FLATPAK_COUNT) --" "$flatpak_list"

    log "${C_BOLD}Arch $REPO_COUNT${C_RESET} $G_DOT ${C_BOLD}AUR $AUR_COUNT${C_RESET} $G_DOT ${C_BOLD}Flatpak $FLATPAK_COUNT${C_RESET}"
    notable="$(printf '%s\n' "$repo_list" | grep -E "$NOTABLE_RE" | awk '{ printf "%s%s %s", (NR > 1 ? ", " : ""), $1, $NF }')"
    [[ -n "$notable" ]] && log "Belangrijk: $notable"
    [[ -n "$aur_list" ]] && log "AUR: $(inline_names "$aur_list")"
    [[ -n "$flatpak_list" ]] && log "Flatpak: $(inline_names "$flatpak_list")"
    [[ -n "$LOG_FILE" ]] && log "${C_DIM}Volledige lijst in het log.${C_RESET}"
    if printf '%s\n' "$repo_list" | grep -qE '^linux(-lts|-zen|-hardened)? '; then
        result warn "Er zit een kernel-update bij; na afloop is een herstart nodig."
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
        result ok "Geen .pacnew- of .pacsave-bestanden in /etc."
        return 0
    fi
    to_log "$files"
    result warn "$(count_lines "$files") configbestand(en) wachten op sudo pacdiff: $(inline_names "$files")"
}

report_reboot() {
    command -v pacman >/dev/null 2>&1 || return 0
    if [[ -d "/usr/lib/modules/$(uname -r)" ]]; then
        result ok "Geen herstart nodig; de draaiende kernel is nog geïnstalleerd."
    else
        result warn "Herstart nodig: de draaiende kernel $(uname -r) is vervangen."
    fi
}

cleanup_system() {
    local orphans=""

    if command -v pacman >/dev/null 2>&1; then
        orphans="$(pacman -Qdtq 2>/dev/null || true)"
        if [[ -n "$orphans" ]]; then
            to_log "$orphans"
            log "Verweesde pakketten ($(count_lines "$orphans")): $(inline_names "$orphans")"
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
        live "Pakketoverzicht maken"
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
        log "Geen geïnstalleerde kingstra-dots git-repo gevonden; overgeslagen."
        return 0
    fi
    DOTFILES_REPO="$repo"

    # Na kingstra-rollback staan de dotfiles bewust vast.
    if [[ -f "$HOLD_FILE" ]]; then
        log "Dotfiles staan vast op $(cat "$HOLD_FILE") na een rollback; niet opgehaald."
        log "Weer meegaan met updates: kingstra-rollback --release"
        return 0
    fi

    branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [[ -z "$branch" ]]; then
        log "Dotfiles-repo staat niet op een branch; overgeslagen."
        return 0
    fi

    live "Dotfiles ophalen"
    if ! git -C "$repo" fetch --quiet origin "$branch"; then
        live_clear
        log "Dotfiles ophalen mislukt."
        return 1
    fi

    live_clear
    upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    if [[ -z "$upstream" ]] && git -C "$repo" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
        upstream="origin/$branch"
    fi
    if [[ -z "$upstream" ]]; then
        log "Geen upstream voor branch '$branch'; overgeslagen."
        return 0
    fi

    behind="$(git -C "$repo" rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
    ahead="$(git -C "$repo" rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)"
    if [[ "$behind" -eq 0 ]]; then
        log "Dotfiles zijn al actueel."
        return 0
    fi

    # Alleen gewijzigde bestanden die git bijhoudt blokkeren de update. Losse
    # nieuwe bestanden (zoals een eigen keep-lijst) kunnen gewoon blijven
    # staan: merge --ff-only weigert zelf als zo'n bestand overschreven zou
    # worden, dus er gaat niets verloren.
    if [[ -n "$(git -C "$repo" status --porcelain --untracked-files=no)" ]]; then
        log "Er staan lokale wijzigingen in $repo:"
        log_block "$(git -C "$repo" status --short --untracked-files=no)"
        log "Dotfiles-update veilig overgeslagen; commit of stash ze eerst."
        return 0
    fi
    if [[ "$ahead" -gt 0 ]]; then
        log "De lokale branch loopt ook $ahead commit(s) voor op upstream."
        log "Automatisch samenvoegen is overgeslagen."
        return 0
    fi

    log "$behind nieuwe dotfiles-commit(s) gevonden."
    if ! git -C "$repo" merge --ff-only --quiet "$upstream"; then
        log "Bijwerken mislukt; waarschijnlijk staat er een los bestand in de weg (zie hierboven)."
        return 1
    fi
}

# Terugzetpunt vóór er iets verandert: git-tag van de dotfiles en, op btrfs
# met snapper, een systeemsnapshot. Mislukt dat, dan gaat de update door.
make_restore_point() {
    if [[ ! -x "$SNAPSHOT_CMD" ]]; then
        result warn "kingstra-snapshot niet gevonden; geen terugzetpunt."
        return 0
    fi
    if $UI && [[ "$(findmnt -no FSTYPE / 2>/dev/null)" == "btrfs" ]] \
        && command -v snapper >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1 \
        && ! sudo -n true 2>/dev/null; then
        live_clear
        sudo -v || true
    fi
    local out=""
    if out="$("$SNAPSHOT_CMD" create "kingstra: voor update" 2>&1)"; then
        to_log "$out"
        result ok "Terugzetpunt gemaakt (terug met: kingstra-rollback)."
    else
        to_log "$out"
        result warn "Terugzetpunt maken mislukt; update gaat door."
    fi
}

run_dotfiles_installer() {
    local repo="$1"
    local installer="$repo/install.sh"

    if [[ ! -f "$installer" ]]; then
        log "Installer niet gevonden: $installer"
        return 1
    fi

    log "Installer bijwerken: pakketten, gegenereerde config en live reload."
    KINGSTRA_UI_EMBEDDED=true bash "$installer" --yes
}

# yay/paru en flatpak bijwerken. In de compacte weergave stil met
# voortgangsbalk; mislukt dat, dan kan de run interactief opnieuw.
update_arch() {
    local helper="" rc=0
    if command -v yay >/dev/null 2>&1; then
        helper="yay"
    elif command -v paru >/dev/null 2>&1; then
        helper="paru"
    else
        result warn "Geen yay of paru gevonden; overgeslagen."
        return 0
    fi

    if ! $UI || $INTERACTIVE; then
        "$helper" -Syu || rc=$?
        return "$rc"
    fi

    local -a flags=(-Syu --noconfirm --sudoloop)
    case "$helper" in
        yay) flags+=(--answerdiff None --answerclean None --answeredit None --answerupgrade None) ;;
        paru) flags+=(--skipreview) ;;
    esac
    # Wachtwoord nu vragen, zodat de stille run niet op sudo blijft hangen.
    if command -v sudo >/dev/null 2>&1 && ! sudo -n true 2>/dev/null; then
        live_clear
        sudo -v || return 1
    fi
    run_quiet "$helper" "$helper" "${flags[@]}" || rc=$?
    if (( rc != 0 )) && ask_yes "Opnieuw draaien met de gewone $helper-uitvoer en vragen?"; then
        rc=0
        "$helper" -Syu || rc=$?
    fi
    return "$rc"
}

update_flatpak() {
    local rc=0
    if ! $UI || $INTERACTIVE; then
        flatpak update || rc=$?
        return "$rc"
    fi
    run_quiet "Flatpak" flatpak update -y --noninteractive || rc=$?
    return "$rc"
}

finish() {
    local code="$1" line kind title msg glyph color
    if $UI; then
        live_clear
        printf '\n  %s%s%s %s100%%%s  %sKlaar%s\n' "$C_GREEN" "$(bar 1 1 14)" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET"
        for line in "${SUMMARY[@]+"${SUMMARY[@]}"}"; do
            IFS='|' read -r kind title msg <<< "$line"
            [[ "$kind" == "ok" ]] && continue
            case "$kind" in
                warn) glyph="$G_WARN"; color="$C_YELLOW" ;;
                *) glyph="$G_FAIL"; color="$C_RED" ;;
            esac
            printf '    %s%s%s %s%s:%s %s\n' "$color" "$glyph" "$C_RESET" "$C_DIM" "$title" "$C_RESET" "$msg"
        done
    else
        section "Klaar"
    fi
    if [[ $code -eq 0 ]]; then
        log "Alle beschikbare updatebronnen zijn verwerkt."
    else
        log "Minstens één updatebron eindigde met een fout (code $code)."
    fi
    [[ -n "$LOG_FILE" ]] && log "${C_DIM}Log: $LOG_FILE${C_RESET}"
    echo
    live_clear
    read -r -p "Druk Enter om te sluiten..." _
}

init_log

if $UI; then
    printf '\n  %sKingstra Update Runner%s  %syay %s Flatpak %s kingstra-dots%s\n' \
        "$C_BOLD" "$C_RESET" "$C_DIM" "$G_DOT" "$G_DOT" "$C_RESET"
else
    echo "=============================================="
    echo " Kingstra Update Runner"
    echo " yay · Flatpak · kingstra-dots"
    echo "=============================================="
fi
to_log "Gestart: $(date '+%Y-%m-%d %H:%M:%S')"

section "Arch-nieuws"
if ! check_arch_news; then
    [[ -n "$LOG_FILE" ]] && log "Log: $LOG_FILE"
    live_clear
    read -r -p "Druk Enter om te sluiten..." _
    exit 0
fi

section "Wat er bijwerkt"
preview_updates
if $UI && ! $INTERACTIVE && (( REPO_COUNT + AUR_COUNT + FLATPAK_COUNT > 0 )); then
    if ! ask_yes "Updates installeren?"; then
        log "Update op verzoek gestopt."
        finish 0
        exit 0
    fi
fi

section "Terugzetpunt"
make_restore_point

section "Arch/AUR"
arch_exit=0
update_arch || arch_exit=$?
[[ $arch_exit -eq 0 ]] || overall_exit=$arch_exit
if [[ $arch_exit -eq 0 ]]; then
    result ok "Arch/AUR bijgewerkt."
else
    result fail "Arch/AUR eindigde met exitcode $arch_exit."
fi

section "Flatpak"
flatpak_exit=0
if command -v flatpak >/dev/null 2>&1; then
    update_flatpak || flatpak_exit=$?
    if [[ $flatpak_exit -eq 0 ]]; then
        result ok "Flatpak bijgewerkt."
    else
        result fail "Flatpak eindigde met exitcode $flatpak_exit."
    fi
else
    log "Flatpak is niet geïnstalleerd; overgeslagen."
fi
[[ $flatpak_exit -eq 0 ]] || overall_exit=$flatpak_exit

section "Dotfiles"
dotfiles_update_exit=0
update_dotfiles || dotfiles_update_exit=$?

# Een git pull alleen is niet genoeg: nieuwe pakketten, gegenereerde hardware-
# config en live sessiewijzigingen worden pas door install.sh toegepast. Draai
# de installer ook als de repo al actueel is, zodat een eerdere half-afgeronde
# update zichzelf kan herstellen.
installer_exit=0
if [[ -n "$DOTFILES_REPO" ]]; then
    run_dotfiles_installer "$DOTFILES_REPO" || installer_exit=$?
    [[ $installer_exit -eq 0 ]] || overall_exit=1
fi

if [[ $dotfiles_update_exit -ne 0 ]]; then
    overall_exit=1
fi

if [[ $dotfiles_update_exit -ne 0 || $installer_exit -ne 0 ]]; then
    result fail "Dotfiles: ophalen of installer mislukt (code $dotfiles_update_exit/$installer_exit)."
else
    result ok "Dotfiles bijgewerkt."
fi

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

finish "$overall_exit"
exit "$overall_exit"
