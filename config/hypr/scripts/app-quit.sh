#!/usr/bin/env bash
# Apps echt sluiten in plaats van naar de systeemtray.
#
# Sommige apps (ChatGPT, chat- en sync-apps) verbergen bij sluiten alleen hun
# venster en blijven op de achtergrond draaien. Voor apps op de lijst
# "echt sluiten" beëindigt de watcher het proces zodra het laatste venster
# dicht is, ook via Super+Q of de X van het venster.
#
# Gebruik: app-quit.sh <actie>
#   watch           luistert naar Hyprland (gestart door kingstra-session-start)
#   active          het actieve venster echt afsluiten (Super+Shift+Q)
#   tray <id>       de app achter een tray-icoon afsluiten (Shift+klik in de tray)
#   list            de lijst, één app-klasse per regel
#   add <klasse>    een app aan de lijst toevoegen
#   remove <klasse> een app van de lijst halen
#   classes         klassen van open vensters, één per regel
#
# De lijst staat in ~/.config/kingstra/close-fully.list: één venster-klasse
# per regel, # voor commentaar. Een regel past op elke klasse waar hij in
# voorkomt, zonder op hoofdletters te letten ("chatgpt" vangt ook
# "com.openai.ChatGPT"). Zolang het bestand niet bestaat geldt de
# standaardlijst hieronder.
set -u

LIST_FILE="${KINGSTRA_CLOSE_FULLY_LIST:-${XDG_CONFIG_HOME:-$HOME/.config}/kingstra/close-fully.list}"
DEFAULT_LIST=("chatgpt")
# Na het sluiten even wachten: een app die een nieuw venster opent (een
# splash die het hoofdvenster wordt) wordt dan niet afgeschoten.
GRACE_SECONDS="${KINGSTRA_CLOSE_GRACE:-1}"
TERM_WAIT_STEPS=30 # x 0.1 s voor SIGKILL
# Processen die nooit beëindigd worden, ook niet op verzoek.
PROTECTED_RE='^(Hyprland|quickshell|qs|systemd|dbus-daemon|dbus-broker|pipewire|wireplumber|sddm|Xwayland)$'

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a Kingstra -i application-exit "$@" >/dev/null 2>&1 || true
}

read_list() {
    if [[ -f "$LIST_FILE" ]]; then
        sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$LIST_FILE" | awk 'NF && !seen[tolower($0)]++'
    else
        printf '%s\n' "${DEFAULT_LIST[@]}"
    fi
}

write_list() {
    local dir tmp
    dir="$(dirname "$LIST_FILE")"
    mkdir -p "$dir" || return 1
    tmp="$(mktemp "$LIST_FILE.tmp.XXXXXX")" || return 1
    {
        printf '# Apps die bij sluiten echt stoppen (zie app-quit.sh).\n'
        printf '# Eén venster-klasse per regel; past ook op een deel van de klasse.\n'
        cat
    } > "$tmp"
    mv -f -- "$tmp" "$LIST_FILE"
}

# matches CLASS: staat de klasse (of een deel ervan) op de lijst?
matches() {
    local class="${1,,}" entry
    [[ -n "$class" ]] || return 1
    while IFS= read -r entry; do
        [[ -n "$entry" && "$class" == *"${entry,,}"* ]] && return 0
    done < <(read_list)
    return 1
}

process_name() {
    cat "/proc/$1/comm" 2>/dev/null
}

# quit_pid PID: netjes stoppen (SIGTERM), na drie seconden hard (SIGKILL).
quit_pid() {
    local pid="$1" name
    [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 && pid != $$ )) || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    name="$(process_name "$pid")"
    [[ "$name" =~ $PROTECTED_RE ]] && return 1
    kill -TERM "$pid" 2>/dev/null || return 1
    local step
    for (( step = 0; step < TERM_WAIT_STEPS; step++ )); do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 0.1
    done
    kill -KILL "$pid" 2>/dev/null
    return 0
}

clients_json() {
    hyprctl clients -j 2>/dev/null || printf '[]'
}

pid_has_window() {
    jq -e --argjson pid "$1" 'any(.[]; .pid == $pid)' <<< "$(clients_json)" >/dev/null 2>&1
}

quit_active() {
    local window pid class name
    window="$(hyprctl activewindow -j 2>/dev/null)" || exit 0
    pid="$(jq -r '.pid // empty' <<< "$window" 2>/dev/null)"
    class="$(jq -r '.class // empty' <<< "$window" 2>/dev/null)"
    [[ -n "$pid" ]] || exit 0
    name="$(process_name "$pid")"
    if quit_pid "$pid"; then
        notify "${class:-$name} afgesloten" "Het proces is beëindigd, niet naar de tray."
    else
        notify "Kan ${class:-$name} niet afsluiten" "Dit proces wordt beschermd of draait al niet meer."
    fi
}

# Proces-ID achter een tray-icoon: de watcher (Quickshell) kent elke
# StatusNotifierItem als "dienst/pad"; de dienst geeft via D-Bus zijn PID.
tray_pid() {
    local wanted="${1,,}" items entry service path id
    command -v busctl >/dev/null 2>&1 || return 1
    items="$(busctl --user --json=short get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
        org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null | jq -r '.data[]?' 2>/dev/null)"
    while IFS= read -r entry; do
        [[ -n "$entry" ]] || continue
        if [[ "$entry" == */* ]]; then
            service="${entry%%/*}"
            path="/${entry#*/}"
        else
            service="$entry"
            path="/StatusNotifierItem"
        fi
        id="$(busctl --user --json=short get-property "$service" "$path" org.kde.StatusNotifierItem Id 2>/dev/null \
            | jq -r '.data // empty' 2>/dev/null)"
        [[ -n "$id" && "${id,,}" == "$wanted" ]] || continue
        busctl --user --json=short call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
            GetConnectionUnixProcessID s "$service" 2>/dev/null | jq -r '.data[0] // empty' 2>/dev/null
        return 0
    done <<< "$items"
    return 1
}

quit_tray() {
    local id="${1:-}" title="${2:-}" pid
    [[ -n "$id" ]] || exit 2
    pid="$(tray_pid "$id")"
    if [[ -n "$pid" ]] && quit_pid "$pid"; then
        notify "${title:-$id} afgesloten" "De app draait niet meer op de achtergrond."
    else
        notify "Kan ${title:-$id} niet afsluiten" "Geen proces gevonden achter dit tray-icoon."
    fi
}

add_class() {
    local class="${1:-}"
    class="${class//$'\n'/}"
    class="${class#"${class%%[![:space:]]*}"}"
    class="${class%"${class##*[![:space:]]}"}"
    [[ -n "$class" ]] || exit 2
    { read_list; printf '%s\n' "$class"; } | awk 'NF && !seen[tolower($0)]++' | write_list
}

remove_class() {
    local class="${1:-}"
    [[ -n "$class" ]] || exit 2
    read_list | awk -v c="${class,,}" 'tolower($0) != c' | write_list
}

open_classes() {
    jq -r '[.[] | select(.mapped != false) | .class | select(. != null and . != "")] | unique | .[]' \
        <<< "$(clients_json)" 2>/dev/null
}

# Na het sluiten van een venster: is de app een lijst-app zonder vensters,
# dan het proces beëindigen.
handle_close() {
    local pid="$1" class="$2"
    matches "$class" || return 0
    sleep "$GRACE_SECONDS"
    pid_has_window "$pid" && return 0
    kill -0 "$pid" 2>/dev/null || return 0
    quit_pid "$pid" || true
}

watch() {
    command -v socat >/dev/null 2>&1 || exit 0
    command -v jq >/dev/null 2>&1 || exit 0
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || exit 0
    local socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    for _ in {1..50}; do
        [[ -S "$socket" ]] && break
        sleep 0.1
    done
    [[ -S "$socket" ]] || exit 0

    # Hyprland noemt bij closewindow alleen het adres; PID en klasse komen
    # uit deze cache, bijgewerkt bij elk nieuw venster.
    declare -A cache=()
    refresh() {
        local addr rest
        cache=()
        while IFS=$'\t' read -r addr rest; do
            [[ -n "$addr" ]] && cache["${addr#0x}"]="$rest"
        done < <(jq -r '.[] | select(.pid > 0) | [.address, .pid, .class] | @tsv' <<< "$(clients_json)" 2>/dev/null)
    }

    refresh
    local event addr entry pid class
    while IFS= read -r event; do
        case "$event" in
            openwindow\>\>*)
                refresh
                ;;
            closewindow\>\>*)
                addr="${event#closewindow>>}"
                entry="${cache[${addr#0x}]:-}"
                unset 'cache[${addr#0x}]'
                [[ -n "$entry" ]] || continue
                IFS=$'\t' read -r pid class <<< "$entry"
                handle_close "$pid" "$class" &
                ;;
        esac
    done < <(socat -u "UNIX-CONNECT:$socket" - 2>/dev/null)
}

case "${1:-}" in
    watch) watch ;;
    active) quit_active ;;
    tray) shift; quit_tray "$@" ;;
    list) read_list ;;
    add) shift; add_class "$@" ;;
    remove) shift; remove_class "$@" ;;
    classes) open_classes ;;
    matches) shift; matches "${1:-}" ;;
    *) echo "Gebruik: $(basename "$0") watch|active|tray <id> [titel]|list|add <klasse>|remove <klasse>|classes" >&2; exit 2 ;;
esac
