#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CONSTANTS & ARGUMENTS
# -----------------------------------------------------------------------------
QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BT_PID_FILE="$HOME/.cache/bt_scan_pid"
BT_SCAN_LOG="$HOME/.cache/bt_scan.log"
FOCUSTIME_DAEMON="$HOME/.config/quickshell/focustime/focus_daemon.py"

IPC_FILE="/tmp/qs_widget_state"
NETWORK_MODE_FILE="/tmp/qs_network_mode"
PREV_FOCUS_FILE="/tmp/qs_prev_focus"

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
    echo "close" > "$IPC_FILE"
    
    # HYPRLAND 0.54+ FIX: Grab exact hex address to prevent regex matching failures
    local qs_addr=$(hyprctl clients -j | jq -r '.[] | select(.title == "qs-master") | .address' | head -n 1)

    (
        sleep 0.15
        if [[ -n "$qs_addr" ]]; then
            hyprctl --batch "dispatch movetoworkspacesilent special:qs-hidden,address:$qs_addr ; dispatch setfloating address:$qs_addr" >/dev/null 2>&1
        fi
        
        # Re-assert focus after the window tree changes to prevent focus drops
        if [[ -n "$prev_addr" && "$prev_addr" != "null" ]]; then
            hyprctl --batch "keyword cursor:no_warps true ; dispatch focuswindow address:$prev_addr ; keyword cursor:no_warps false" >/dev/null 2>&1
        fi
    ) &
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

qs_master_workspace() {
    hyprctl clients -j 2>/dev/null \
        | jq -r '.[] | select(.title == "qs-master") | .workspace.name' \
        | head -n 1
}

qs_master_visible() {
    local ws_name
    ws_name="$(qs_master_workspace)"
    [[ -n "$ws_name" && "$ws_name" != "null" && "$ws_name" != special:* ]]
}

non_quickshell_client_filter='.title != "qs-master" and .class != "org.quickshell" and .initialClass != "org.quickshell"'

# -----------------------------------------------------------------------------
# FAST PATH: WORKSPACE SWITCHING
# -----------------------------------------------------------------------------
if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    WORKSPACE_NUM="$ACTION"
    MOVE_OPT="$2"
    CURRENT_WS=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')
    if ! [[ "$CURRENT_WS" =~ ^-?[0-9]+$ ]] || (( CURRENT_WS < 1 )); then
        CURRENT_WS=1
    fi
    TARGET_WS=$(( ((CURRENT_WS - 1) / 10) * 10 + WORKSPACE_NUM ))
    
    echo "close" > "$IPC_FILE"

    # HYPRLAND 0.54+ FIX: For workspace switching, we skip the 0.15s animation sleep 
    # and banish the widget instantly. This prevents the delayed window move from 
    # stealing focus on the newly activated workspace.
    QS_ADDR=$(hyprctl clients -j | jq -r '.[] | select(.title == "qs-master") | .address' | head -n 1)
    if [[ -n "$QS_ADDR" ]]; then
        hyprctl --batch "dispatch movetoworkspacesilent special:qs-hidden,address:$QS_ADDR ; dispatch setfloating address:$QS_ADDR" >/dev/null 2>&1
    fi
    
    CMD="workspace $TARGET_WS"
    [[ "$MOVE_OPT" == "move" ]] && CMD="movetoworkspace $TARGET_WS"

    TARGET_ADDR=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $TARGET_WS and $non_quickshell_client_filter) | .address" | head -n 1)

    if [[ -n "$TARGET_ADDR" && "$TARGET_ADDR" != "null" ]]; then
        hyprctl --batch "dispatch $CMD ; keyword cursor:no_warps true ; dispatch focuswindow address:$TARGET_ADDR ; keyword cursor:no_warps false" >/dev/null 2>&1
    else
        hyprctl --batch "dispatch $CMD" >/dev/null 2>&1
    fi
    
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
MAIN_QML_PATH="$HOME/.config/quickshell/Main.qml"
BAR_QML_PATH="$HOME/.config/quickshell/TopBar.qml"

QS_PID=$(pgrep -f "quickshell.*Main\.qml")
WIN_EXISTS=$(hyprctl clients -j | grep "qs-master")
BAR_PID=$(pgrep -f "quickshell.*TopBar\.qml")

if [[ -z "$QS_PID" ]] || [[ -z "$WIN_EXISTS" ]]; then
    if [[ -n "$QS_PID" ]]; then
        kill -9 $QS_PID 2>/dev/null
    fi
    
    # Bypass NixOS symlink resolution by using the direct ~/.config path
    quickshell -p "$MAIN_QML_PATH" >/dev/null 2>&1 &
    disown
    
    for _ in {1..20}; do
        if hyprctl clients -j | grep -q "qs-master"; then
            sleep 0.1
            break
        fi
        sleep 0.05
    done
fi

if [[ -z "$BAR_PID" ]]; then
    quickshell -p "$BAR_QML_PATH" >/dev/null 2>&1 &
    disown
fi

# -----------------------------------------------------------------------------
# FOCUS MANAGEMENT
# -----------------------------------------------------------------------------
save_and_focus_widget() {
    # Only save if the currently focused window is NOT the widget container
    local current_window=$(hyprctl activewindow -j 2>/dev/null)
    local current_title=$(echo "$current_window" | jq -r '.title // empty')
    local current_class=$(echo "$current_window" | jq -r '.class // empty')
    local current_initial_class=$(echo "$current_window" | jq -r '.initialClass // empty')
    local current_addr=$(echo "$current_window" | jq -r '.address // empty')
    
    # Grab the active workspace so we can pull the widget to us
    local active_ws=$(hyprctl activeworkspace -j | jq -r '.id')

    if [[ "$current_title" != "qs-master" && "$current_class" != "org.quickshell" && "$current_initial_class" != "org.quickshell" && -n "$current_addr" && "$current_addr" != "null" ]]; then
        echo "$current_addr" > "$PREV_FOCUS_FILE"
    fi

    # Dispatch focus without warping the cursor (run async with a tiny delay to allow QML to move the window first)
    (
        sleep 0.05
        # FOOLPROOF FIX: Pull the widget back from the hidden workspace to the active one silently, THEN focus it.
        hyprctl --batch "keyword cursor:no_warps true ; dispatch movetoworkspacesilent $active_ws,title:^qs-master$ ; dispatch setfloating title:^qs-master$ ; dispatch focuswindow title:^qs-master$ ; keyword cursor:no_warps false" >/dev/null 2>&1
    ) &
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
    QS_VISIBLE=false
    if qs_master_visible; then
        QS_VISIBLE=true
    fi

    # Guard tegen stale state-file (bijv. na herstart/login zonder actieve popup).
    # Toggle-close mag alleen als qs-master daadwerkelijk zichtbaar is.
    if [[ "$QS_VISIBLE" != "true" ]]; then
        ACTIVE_WIDGET="hidden"
    fi

    # Dynamically fetch focused monitor geometry and adjust for Wayland layout scale
    ACTIVE_MON=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true)')
    MX=$(echo "$ACTIVE_MON" | jq -r '.x // 0')
    MY=$(echo "$ACTIVE_MON" | jq -r '.y // 0')
    MW=$(echo "$ACTIVE_MON" | jq -r '(.width / (.scale // 1)) | round // 1920')
    MH=$(echo "$ACTIVE_MON" | jq -r '(.height / (.scale // 1)) | round // 1080')

    MON_DATA="${MX}:${MY}:${MW}:${MH}"

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
            echo "$TARGET::$MON_DATA" > "$IPC_FILE"
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
    elif [[ "$TARGET" == "theme" ]]; then
        echo "$TARGET::$MON_DATA" > "$IPC_FILE"
    else
        echo "$TARGET::$MON_DATA" > "$IPC_FILE"
    fi
    
    save_and_focus_widget
    exit 0
fi
