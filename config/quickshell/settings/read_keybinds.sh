#!/usr/bin/env bash
# =============================================================================
# read_keybinds.sh — Parse Hyprland bind files → JSON for SettingsPopup
# =============================================================================
CONF_DIR="${HOME}/.config/hypr/conf.d"
OUTPUT="/tmp/qs_keybinds.json"

# Fallback dispatcher → label (when no inline # comment exists)
declare -A DISPATCHER_LABELS=(
    ["killactive"]="Venster sluiten"
    ["togglefloating"]="Zwevend wisselen"
    ["fullscreen"]="Volledig scherm"
    ["pseudo"]="Pseudo-tiling"
    ["pin"]="Venster vastzetten"
    ["togglegroup"]="Groepsmodus"
    ["moveoutofgroup"]="Uit groep halen"
    ["centerwindow"]="Venster centreren"
    ["togglespecialworkspace"]="Scratchpad"
    ["exit"]="Sessie afsluiten"
)

# Dispatcher+arg → label
fallback_label() {
    local d="$1" args="$2"
    # Check exact dispatcher match
    [[ -n "${DISPATCHER_LABELS[$d]}" ]] && { echo "${DISPATCHER_LABELS[$d]}"; return; }
    case "$d" in
        movefocus)
            case "$args" in
                l) echo "Focus naar links" ;; r) echo "Focus naar rechts" ;;
                u) echo "Focus omhoog"     ;; d) echo "Focus omlaag" ;;
                *) echo "Focus verplaatsen" ;;
            esac ;;
        movewindow)
            case "$args" in
                l) echo "Venster naar links" ;; r) echo "Venster naar rechts" ;;
                u) echo "Venster omhoog"     ;; d) echo "Venster omlaag" ;;
                *) echo "Venster verplaatsen" ;;
            esac ;;
        resizeactive) echo "Venster aanpassen" ;;
        workspace)
            if [[ "$args" =~ ^[0-9]+$ ]]; then echo "Werkruimte $args"
            elif [[ "$args" == "previous" ]]; then echo "Vorige werkruimte"
            elif [[ "$args" == e+* ]]; then echo "Volgende werkruimte"
            elif [[ "$args" == e-* ]]; then echo "Vorige werkruimte"
            else echo "Werkruimte"; fi ;;
        movetoworkspace)
            if [[ "$args" =~ ^[0-9]+$ ]]; then echo "Naar werkruimte $args"
            elif [[ "$args" == special:* ]]; then echo "Naar scratchpad"
            else echo "Venster verplaatsen"; fi ;;
        movetoworkspacesilent)
            if [[ "$args" =~ ^[0-9]+$ ]]; then echo "Stil naar werkruimte $args"
            else echo "Stil verplaatsen"; fi ;;
        changegroupactive)
            case "$args" in f) echo "Volgende groepstab" ;; b) echo "Vorige groepstab" ;; *) echo "Groepstab" ;; esac ;;
        lockactivegroup) echo "Groep vergrendelen" ;;
        layoutmsg) echo "Layout-opdracht" ;;
        exec) echo "${args##*/}" ;;   # Use basename of command
        *) echo "$d" ;;
    esac
}

echo "[" > "$OUTPUT"
first=true

for f in "$CONF_DIR"/8*-binds*.conf; do
    [[ -f "$f" ]] || continue
    fname=$(basename "$f")
    category="${fname#*binds-}"
    category="${category%.conf}"

    linenum=0
    while IFS= read -r line; do
        linenum=$((linenum + 1))

        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        # Match: bind[eml]* = ...
        if [[ "$line" =~ ^(bind[emlr]*)[[:space:]]*=[[:space:]]*(.*) ]]; then
            bindtype="${BASH_REMATCH[1]}"
            rest="${BASH_REMATCH[2]}"

            # Extract inline comment
            comment=""
            if [[ "$rest" =~ (.+)[[:space:]]+#[[:space:]]*(.*) ]]; then
                rest="${BASH_REMATCH[1]}"
                comment="${BASH_REMATCH[2]}"
            fi

            # Split by comma
            IFS=',' read -ra parts <<< "$rest"
            [[ ${#parts[@]} -lt 3 ]] && continue

            mods=$(echo "${parts[0]}" | xargs)
            key=$(echo "${parts[1]}" | xargs)
            dispatcher=$(echo "${parts[2]}" | xargs)

            args=""
            for (( i=3; i<${#parts[@]}; i++ )); do
                [[ -n "$args" ]] && args+=", "
                args+="$(echo "${parts[$i]}" | xargs)"
            done

            # JSON-escape strings
            comment="${comment//\\/\\\\}"
            comment="${comment//\"/\\\"}"
            args="${args//\\/\\\\}"
            args="${args//\"/\\\"}"

            # Use fallback label if no inline comment
            if [[ -z "$comment" ]]; then
                comment=$(fallback_label "$dispatcher" "$args")
                comment="${comment//\\/\\\\}"
                comment="${comment//\"/\\\"}"
            fi

            $first || echo "," >> "$OUTPUT"
            first=false
            printf '  {"file":"%s","cat":"%s","ln":%d,"t":"%s","mods":"%s","key":"%s","d":"%s","args":"%s","label":"%s"}' \
                "$fname" "$category" "$linenum" "$bindtype" "$mods" "$key" "$dispatcher" "$args" "$comment" >> "$OUTPUT"
        fi
    done < "$f"
done

echo -e "\n]" >> "$OUTPUT"
