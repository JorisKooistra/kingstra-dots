#!/usr/bin/env bash
# The former line editor targeted the removed Hyprlang conf.d files. Refuse a
# write explicitly instead of silently creating obsolete configuration again.
printf '%s\n' 'De keybind-editor ondersteunt de Lua-configuratie nog niet; bewerk ~/.config/hypr/lua/binds.lua.' >&2
exit 1
