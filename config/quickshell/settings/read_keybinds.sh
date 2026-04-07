#!/usr/bin/env bash
# =============================================================================
# read_keybinds.sh — Parse Hyprland bind files → JSON for SettingsPopup
# =============================================================================
CONF_DIR="${HOME}/.config/hypr/conf.d"
OUTPUT="/tmp/qs_keybinds.json"

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

            $first || echo "," >> "$OUTPUT"
            first=false
            printf '  {"file":"%s","cat":"%s","ln":%d,"t":"%s","mods":"%s","key":"%s","d":"%s","args":"%s","label":"%s"}' \
                "$fname" "$category" "$linenum" "$bindtype" "$mods" "$key" "$dispatcher" "$args" "$comment" >> "$OUTPUT"
        fi
    done < "$f"
done

echo -e "\n]" >> "$OUTPUT"
