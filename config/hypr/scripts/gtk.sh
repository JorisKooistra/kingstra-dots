#!/usr/bin/env bash
# =============================================================================
# gtk.sh — GTK-instellingen toepassen in een Wayland-sessie
# =============================================================================

# Cursor-thema doorgeven
XCURSOR_THEME="${XCURSOR_THEME:-Bibata-Modern-Classic}"
XCURSOR_SIZE="${XCURSOR_SIZE:-24}"

export XCURSOR_THEME XCURSOR_SIZE
gsettings set org.gnome.desktop.interface cursor-theme  "$XCURSOR_THEME" 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-size   "$XCURSOR_SIZE"  2>/dev/null || true

# GTK-thema, licht/donker, letter en iconen komen uit het actieve thema
# (kingstra-apps-sync bewaart dat als app-profiel). Vroeger stonden hier vaste
# waarden die bij elke login het thema overschreven: Paper bleef dan donker.
APPS_SYNC="$HOME/.local/bin/kingstra-apps-sync"
if [[ -x "$APPS_SYNC" ]] && "$APPS_SYNC" --login 2>/dev/null; then
    exit 0
fi

# Vangnet zonder Kingstra-scripts (eerste start, kapotte installatie).
gsettings set org.gnome.desktop.interface gtk-theme     "adw-gtk3-dark"  2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme    "Papirus-Dark"   2>/dev/null || true
gsettings set org.gnome.desktop.interface font-name     "Fira Sans 11"   2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme  "prefer-dark"    2>/dev/null || true
