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

# GTK-thema
gsettings set org.gnome.desktop.interface gtk-theme     "adw-gtk3-dark"  2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme    "Papirus-Dark"   2>/dev/null || true
gsettings set org.gnome.desktop.interface font-name     "Fira Sans 11"   2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme  "prefer-dark"    2>/dev/null || true
