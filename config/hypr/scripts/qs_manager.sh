#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CONSTANTS & ARGUMENTS
# -----------------------------------------------------------------------------
QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BT_PID_FILE="$HOME/.cache/bt_scan_pid"
BT_SCAN_LOG="$HOME/.cache/bt_scan.log"
FOCUSTIME_DAEMON="$HOME/.config/quickshell/focustime/focus_daemon.py"
export QML_IMPORT_PATH="$HOME/.local/lib/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"

NETWORK_MODE_FILE="/tmp/qs_network_mode"
PREV_FOCUS_FILE="/tmp/qs_prev_focus"

qs_ipc_send() {
    # Voeg $RANDOM toe als nonce zodat onInternalTextChanged altijd vuurt,
    # ook bij herhaald dezelfde widget openen. De parser in Main.qml negeert
    # het extra veld (parts[6+]).
    printf '%s:%s\n' "$1" "$RANDOM" > /tmp/qs_widget_state
}

qs_ipc_close() {
    qs_ipc_send "close"
    printf 'hidden' > /tmp/qs_active_widget
}

ACTION="$1"
TARGET="$2"
SUBTARGET="$3"

ensure_focustime_daemon() {
    [[ -f "$FOCUSTIME_DAEMON" ]] || return 0
    if ! pgrep -f "python3 .*focustime/focus_daemon\\.py" >/dev/null 2>&1; then
        python3 "$FOCUSTIME_DAEMON" >/dev/null 2>&1 &
        disown
    fi
}

if [[ "$TARGET" == "focustime" ]]; then
    ensure_focustime_daemon
fi

# -----------------------------------------------------------------------------
# HYPRLAND 0.54+ FIX: ASYNC HIDE WITH FOCUS RE-ASSERTION
# -----------------------------------------------------------------------------
# In Hyprland 0.54+, moving a window to a special workspace triggers a focus 
# recalculation that can drop focus. We pass the previous address into this 
# function to explicitly re-assert focus AFTER the window is moved.
hide_widget_async() {
    local prev_addr="$1"
    # Writing "close" to the state file triggers Main.qml FileView watcher,
    # which unmaps the WlrLayer.Overlay PanelWindow. No hyprctl dispatch needed.
    qs_ipc_close

    # Restore focus to the previously active window (layer-shell exclusive focus
    # may hold it until the surface unmaps; give it a short head-start).
    if [[ -n "$prev_addr" && "$prev_addr" != "null" ]]; then
        (
            sleep 0.15
            hyprctl --batch "keyword cursor:no_warps true ; dispatch focuswindow address:$prev_addr ; keyword cursor:no_warps false" >/dev/null 2>&1
        ) &
    fi
}

restore_focus() {
    local prev_addr=""
    if [[ -f "$PREV_FOCUS_FILE" ]]; then
        prev_addr=$(cat "$PREV_FOCUS_FILE")
        if [[ -n "$prev_addr" && "$prev_addr" != "null" ]]; then
            hyprctl --batch "keyword cursor:no_warps true ; dispatch focuswindow address:$prev_addr ; keyword cursor:no_warps false" >/dev/null 2>&1
        fi
        rm -f "$PREV_FOCUS_FILE"
    fi
    # Echo the address so hide_widget_async can use it for the double-check
    echo "$prev_addr"
}

qs_master_visible() {
    local qs_pid active_widget
    qs_pid="$(pgrep -f "quickshell.*Main\\.qml" | head -n 1 || true)"
    active_widget="$(cat /tmp/qs_active_widget 2>/dev/null)"
    [[ -n "$qs_pid" && -n "$active_widget" && "$active_widget" != "hidden" ]]
}

non_quickshell_client_filter='.title != "qs-master" and .class != "org.quickshell" and .initialClass != "org.quickshell"'

workspace_cursor_dispatches() {
    local target_ws="$1"
    local monitor_line monitor_name monitor_x monitor_y monitor_w monitor_h cursor_x cursor_y

    monitor_line="$(
        hyprctl monitors -j 2>/dev/null \
            | jq -r --argjson ws "$target_ws" '
                .[]
                | select(.activeWorkspace.id == $ws)
                | [.name, .x, .y, .width, .height]
                | @tsv
            ' \
            | head -n 1 || true
    )"

    [[ -n "$monitor_line" ]] || return 0

    IFS=$'\t' read -r monitor_name monitor_x monitor_y monitor_w monitor_h <<< "$monitor_line"
    [[ -n "$monitor_name" ]] || return 0
    [[ "$monitor_x" =~ ^-?[0-9]+$ && "$monitor_y" =~ ^-?[0-9]+$ ]] || return 0
    [[ "$monitor_w" =~ ^[0-9]+$ && "$monitor_h" =~ ^[0-9]+$ ]] || return 0

    cursor_x=$((monitor_x + monitor_w / 2))
    cursor_y=$((monitor_y + monitor_h / 2))

    printf 'dispatch focusmonitor %s ; dispatch movecursor %s %s' "$monitor_name" "$cursor_x" "$cursor_y"
}

dispatch_workspace_target() {
    local target_ws="$1"
    local move_opt="${2:-}"
    local cmd target_addr cursor_dispatches batch_cmd

    cmd="workspace $target_ws"
    [[ "$move_opt" == "move" ]] && cmd="movetoworkspace $target_ws"

    target_addr=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $target_ws and $non_quickshell_client_filter) | .address" | head -n 1)
    cursor_dispatches="$(workspace_cursor_dispatches "$target_ws")"

    if [[ -n "$target_addr" && "$target_addr" != "null" ]]; then
        batch_cmd="dispatch $cmd ; keyword cursor:no_warps true ; dispatch focuswindow address:$target_addr ; keyword cursor:no_warps false"
    else
        batch_cmd="dispatch $cmd"
    fi

    if [[ -n "$cursor_dispatches" ]]; then
        batch_cmd="$batch_cmd ; $cursor_dispatches"
    fi

    hyprctl --batch "$batch_cmd" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# FAST PATH: WORKSPACE SWITCHING
# -----------------------------------------------------------------------------
if [[ "$ACTION" == "workspace" && "$TARGET" =~ ^[0-9]+$ ]]; then
    TARGET_WS="$TARGET"
    MOVE_OPT="$SUBTARGET"

    qs_ipc_close
    dispatch_workspace_target "$TARGET_WS" "$MOVE_OPT"
    rm -f "$PREV_FOCUS_FILE"
    exit 0
fi

if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    WORKSPACE_NUM="$ACTION"
    MOVE_OPT="$2"
    CURRENT_WS=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')
    if ! [[ "$CURRENT_WS" =~ ^-?[0-9]+$ ]] || (( CURRENT_WS < 1 )); then
        CURRENT_WS=1
    fi
    TARGET_WS=$(( ((CURRENT_WS - 1) / 10) * 10 + WORKSPACE_NUM ))
    qs_ipc_close
    dispatch_workspace_target "$TARGET_WS" "$MOVE_OPT"
    rm -f "$PREV_FOCUS_FILE"
    exit 0
fi

handle_network_prep() {
    echo "" > "$BT_SCAN_LOG"
    { echo "scan on"; sleep infinity; } | stdbuf -oL bluetoothctl > "$BT_SCAN_LOG" 2>&1 &
    echo $! > "$BT_PID_FILE"
    (nmcli device wifi rescan) &
}

# -----------------------------------------------------------------------------
# ENSURE MASTER WINDOW & TOP BAR ARE ALIVE (ZOMBIE WATCHDOG)
# -----------------------------------------------------------------------------
BAR_QML_PATH="$HOME/.config/quickshell/TopBar.qml"

QS_PID=$(pgrep -f "quickshell.*Main\.qml")
BAR_PID=$(pgrep -f "quickshell.*TopBar\.qml")

# Main.qml now uses a WlrLayer.Overlay PanelWindow which does NOT appear in
# hyprctl clients — only check process existence.
if [[ -z "$QS_PID" ]]; then
    # Maak het state-bestand aan vóór Main.qml start, zodat FileView het
    # direct kan bekijken (Qt's inotify vereist dat het bestand bestaat).
    # Leeg het meteen: een achtergebleven widgetnaam van de vorige sessie zou
    # anders bij het opstarten direct dat paneel heropenen.
    : > /tmp/qs_widget_state 2>/dev/null || true
    printf 'hidden' > /tmp/qs_active_widget 2>/dev/null || true
    quickshell --no-duplicate -p "$HOME/.config/quickshell/Main.qml" >/dev/null 2>&1 &
    disown
    sleep 0.3
fi

if [[ -z "$BAR_PID" ]]; then
    quickshell --no-duplicate -p "$BAR_QML_PATH" >/dev/null 2>&1 &
    disown
fi

# -----------------------------------------------------------------------------
# FOCUS MANAGEMENT
# -----------------------------------------------------------------------------
save_and_focus_widget() {
    # Save the currently focused window address so restore_focus can return to it.
    # The WlrLayer.Overlay PanelWindow is handled entirely by the layer-shell
    # protocol — no hyprctl dispatch needed to show or focus it.
    # Eén jq-aanroep i.p.v. vier losse: elk veld op een eigen regel. mapfile
    # bewaart ook lege velden (een tab-gescheiden read zou opeenvolgende lege
    # velden samenvouwen omdat tab een whitespace-IFS is).
    local fields
    mapfile -t fields < <(
        hyprctl activewindow -j 2>/dev/null \
            | jq -r '.title // "", .class // "", .initialClass // "", .address // ""'
    )
    local current_title="${fields[0]:-}"
    local current_class="${fields[1]:-}"
    local current_initial_class="${fields[2]:-}"
    local current_addr="${fields[3]:-}"

    if [[ "$current_title" != "qs-master" && "$current_class" != "org.quickshell" && "$current_initial_class" != "org.quickshell" && -n "$current_addr" && "$current_addr" != "null" ]]; then
        echo "$current_addr" > "$PREV_FOCUS_FILE"
    fi
}

# -----------------------------------------------------------------------------
# REMAINING ACTIONS (OPEN / CLOSE / TOGGLE)
# -----------------------------------------------------------------------------
if [[ "$ACTION" == "close" ]]; then
    PREV=$(restore_focus)
    hide_widget_async "$PREV"
    
    if [[ "$TARGET" == "network" || "$TARGET" == "all" || -z "$TARGET" ]]; then
        if [ -f "$BT_PID_FILE" ]; then
            kill $(cat "$BT_PID_FILE") 2>/dev/null
            rm -f "$BT_PID_FILE"
        fi
        # Backgrounded to prevent DBus from hanging the script for 1s
        (bluetoothctl scan off > /dev/null 2>&1) &
    fi
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    ACTIVE_WIDGET=$(cat /tmp/qs_active_widget 2>/dev/null)
    CURRENT_MODE=$(cat "$NETWORK_MODE_FILE" 2>/dev/null)

    # Surface-native panelen leven in de shell-surface en hebben de legacy
    # qs-master focus-machinerie niet nodig. Die zou hier juist de
    # HyprlandFocusGrab verbreken, waardoor het paneel direct weer sluit.
    SURFACE_NATIVE=" launcher power notifications mail "
    if [[ "$SURFACE_NATIVE" == *" $TARGET "* ]]; then
        if [[ "$ACTION" == "toggle" && "$ACTIVE_WIDGET" == "$TARGET" ]]; then
            qs_ipc_close
        else
            qs_ipc_send "$TARGET"
            printf '%s' "$TARGET" > /tmp/qs_active_widget
        fi
        exit 0
    fi
    QS_VISIBLE=false
    if qs_master_visible; then
        QS_VISIBLE=true
    fi

    # Guard tegen stale state-file (bijv. na herstart/login zonder actieve popup).
    # Toggle-close mag alleen als qs-master daadwerkelijk zichtbaar is.
    if [[ "$QS_VISIBLE" != "true" ]]; then
        ACTIVE_WIDGET="hidden"
    fi

    # Monitor payload is optional; Main.qml can fall back to Hyprland.focusedMonitor.
    MON_DATA=""
    MON_LINE="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | [(.x // 0), (.y // 0), ((.width / (.scale // 1)) | round), ((.height / (.scale // 1)) | round)] | @tsv' | head -n 1 || true)"
    if [[ -n "$MON_LINE" ]]; then
        IFS=$'\t' read -r MX MY MW MH <<< "$MON_LINE"
        if [[ "$MX" =~ ^-?[0-9]+$ && "$MY" =~ ^-?[0-9]+$ && "$MW" =~ ^[0-9]+$ && "$MH" =~ ^[0-9]+$ ]]; then
            MON_DATA="${MX}:${MY}:${MW}:${MH}"
        fi
    fi

    if [[ "$TARGET" == "network" ]]; then
        if [[ "$ACTION" == "toggle" && "$ACTIVE_WIDGET" == "network" ]]; then
            if [[ -n "$SUBTARGET" ]]; then
                if [[ "$CURRENT_MODE" == "$SUBTARGET" ]]; then
                    PREV=$(restore_focus)
                    hide_widget_async "$PREV"
                else
                    echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
                    save_and_focus_widget
                fi
            else
                PREV=$(restore_focus)
                hide_widget_async "$PREV"
            fi
        else
            handle_network_prep
            if [[ -n "$SUBTARGET" ]]; then
                echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
            fi
            if [[ -n "$MON_DATA" ]]; then
                qs_ipc_send "$TARGET::$MON_DATA"
            else
                qs_ipc_send "$TARGET"
            fi
            save_and_focus_widget
        fi
        exit 0
    fi

    # Intercept toggle logic for all other widgets so we can restore focus properly
    if [[ "$ACTION" == "toggle" && "$ACTIVE_WIDGET" == "$TARGET" ]]; then
        PREV=$(restore_focus)
        hide_widget_async "$PREV"
        exit 0
    fi

    if [[ "$TARGET" == "wallpaper" ]]; then
        "$QS_DIR/wallpaper-picker-safe.sh" >/dev/null 2>&1 &
        exit 0
    fi

    if [[ -n "$MON_DATA" ]]; then
        qs_ipc_send "$TARGET::$MON_DATA"
    else
        qs_ipc_send "$TARGET"
    fi
    
    save_and_focus_widget
    exit 0
fi
