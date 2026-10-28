#!/usr/bin/env bash
# Kingstra Instellingen als eigen app.
#
# De instellingen draaien in een eigen quickshell-proces
# (quickshell/SettingsApp.qml) met app-id "kingstra-settings". Daardoor is
# het een gewoon venster: in de launcher, in Alt-tab en het overzicht,
# tegelbaar met Super+T, en het werkt ook als de bar of de surface hangt of
# gecrasht is. Sluit je het venster, dan stopt het proces.
#
# Gebruik: settings-app.sh [open|toggle|close] [pagina]
#   pagina = thema, geluid, bediening, ... (zie settings/SettingIndex.js)
#
# Draait de app al, dan gaat het verzoek via /tmp/kingstra-settings-request
# ("<actie>:<pagina>:<nonce>"); anders start dit script hem met de pagina in
# KINGSTRA_SETTINGS_PAGE.
set -u

ACTION="${1:-open}"
PAGE="${2:-}"
PAGE="${PAGE//:/}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
APP_QML="$CONFIG_HOME/quickshell/SettingsApp.qml"
REQUEST_FILE="/tmp/kingstra-settings-request"
APP_PATTERN="quickshell.*SettingsApp\\.qml"

case "$ACTION" in
    open|toggle|close) ;;
    *) echo "Gebruik: $(basename "$0") [open|toggle|close] [pagina]" >&2; exit 2 ;;
esac

if pgrep -f "$APP_PATTERN" >/dev/null 2>&1; then
    printf '%s:%s:%s\n' "$ACTION" "$PAGE" "$RANDOM$RANDOM" > "$REQUEST_FILE"
    exit 0
fi

[[ "$ACTION" == "close" ]] && exit 0

if [[ ! -f "$APP_QML" ]]; then
    echo "SettingsApp.qml niet gevonden: $APP_QML" >&2
    exit 1
fi

export QML_IMPORT_PATH="$HOME/.local/lib/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
# De pragma in SettingsApp.qml zet de app-id ook; dit dekt een quickshell
# die de pragma nog niet kent (QS_APP_ID bestaat sinds dezelfde versie).
export QS_APP_ID="kingstra-settings"
export KINGSTRA_SETTINGS_PAGE="$PAGE"
# --no-duplicate vangt twee snelle toetsaanslagen op voordat pgrep het
# eerste proces ziet. setsid: los van de shell of het script dat ons startte.
setsid -f quickshell --no-duplicate -p "$APP_QML" >/dev/null 2>&1 < /dev/null
