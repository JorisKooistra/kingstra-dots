#!/usr/bin/env bash
# The editable keybinding UI used the removed Hyprlang conf.d files. Lua binds
# are executable configuration rather than line-oriented data, so this helper
# intentionally returns an empty model until that UI has a Lua-native editor.
printf '[]\n'
