//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "WindowRegistry.js" as Registry

// Full-screen layer-shell overlay per active monitor.
// ProxyFloatingWindow does not register as a hyprctl client and exposes no
// x/y API, so we use a WlrLayer.Overlay PanelWindow instead. Content is
// positioned inside the fullscreen surface via Item.x/y relative to the
// screen's virtual origin.
PanelWindow {
    id: masterWindow

    // QSettings (QML Settings-type) vereist een organisatienaam; zonder deze
    // faalt de init en persisteert o.a. de audio-cache in VolumePopup niet.
    Component.onCompleted: {
        Qt.application.organization = "kingstra";
    }

    // Dynamically select the screen that hosts the active monitor.
    // activeMx/activeMy are updated from the IPC message before currentActive
    // changes, so the correct screen is always selected before the window maps.
    screen: {
        for (let i = 0; i < Quickshell.screens.length; i++) {
            let s   = Quickshell.screens[i];
            let mon = Hyprland.monitorFor(s);
            if (mon && mon.x === activeMx && mon.y === activeMy) return s;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    // Map the surface only when a widget is active; this also releases
    // keyboard focus and removes the transparent input blocker when idle.
    visible: currentActive !== "hidden"

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "quickshell:qs-master"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.OnDemand
                                           : WlrKeyboardFocus.None

    // ── Active monitor ─────────────────────────────────────────────────────
    property int activeMx: 0
    property int activeMy: 0
    property int activeMw: 1920
    property int activeMh: 1080

    // Virtual origin of the current screen (for content positioning).
    // activeMx/activeMy come from the IPC message that also selected this screen,
    // so they are always the correct offset without needing Hyprland.monitorFor.
    readonly property int screenOffsetX: activeMx
    readonly property int screenOffsetY: activeMy

    // Refresh layout when the screen changes (e.g. resolution change).
    onScreenChanged: {
        if (currentActive !== "hidden") refreshMonitorBounds();
    }

    function refreshMonitorBounds() {
        var mon = Hyprland.focusedMonitor;
        if (!mon || currentActive === "hidden") return;
        activeMx = mon.x;
        activeMy = mon.y;
        activeMw = Math.round(mon.width / (mon.scale || 1));
        activeMh = Math.round(mon.height / (mon.scale || 1));
        var t = getLayout(currentActive);
        if (t) { currentX = t.x; currentY = t.y; }
    }

    function syncFocusedMonitorBounds() {
        var mon = Hyprland.focusedMonitor;
        if (!mon) return;
        activeMx = mon.x;
        activeMy = mon.y;
        activeMw = Math.round(mon.width / (mon.scale || 1));
        activeMh = Math.round(mon.height / (mon.scale || 1));
    }

    // ── Widget state ───────────────────────────────────────────────────────
    property string currentActive: "hidden"
    onCurrentActiveChanged: {
        Quickshell.execDetached(["bash", "-c", "echo '" + currentActive + "' > /tmp/qs_active_widget"]);
    }

    property bool   isVisible:             false
    property string activeArg:             ""
    property bool   disableMorph:          false
    property bool   isWallpaperTransition: false
    property int    morphDuration:         500
    property int    currentX:              0
    property int    currentY:              0
    property real   animW:                 1
    property real   animH:                 1

    function getLayout(name) {
        return Registry.getLayout(
            name, activeMx, activeMy, activeMw, activeMh,
            TouchProfile.windowScale, ThemeConfig.theme, ThemeConfig.barPosition
        );
    }

    // ── Widget content ─────────────────────────────────────────────────────
    Item {
        // Position relative to this screen's virtual origin.
        x: masterWindow.currentX - masterWindow.screenOffsetX
        y: masterWindow.currentY - masterWindow.screenOffsetY
        width:  masterWindow.animW
        height: masterWindow.animH
        clip: true

        Behavior on width  { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutCubic } }

        opacity: masterWindow.isVisible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: masterWindow.isWallpaperTransition ? 150
                        : (masterWindow.morphDuration === 500 ? 300 : 200)
                easing.type: Easing.InOutSine
            }
        }

        Item {
            anchors.centerIn: parent
            width:  masterWindow.currentActive !== "hidden" && getLayout(masterWindow.currentActive)
                    ? getLayout(masterWindow.currentActive).w : 1
            height: masterWindow.currentActive !== "hidden" && getLayout(masterWindow.currentActive)
                    ? getLayout(masterWindow.currentActive).h : 1

            StackView {
                id: widgetStack
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: {
                    Quickshell.execDetached([
                        "bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"
                    ])
                    event.accepted = true
                }

                onCurrentItemChanged: {
                    if (currentItem) currentItem.forceActiveFocus();
                }

                replaceEnter: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 400; easing.type: Easing.OutExpo }
                        NumberAnimation { property: "scale";   from: 0.98; to: 1.0; duration: 400; easing.type: Easing.OutBack }
                    }
                }
                replaceExit: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 300; easing.type: Easing.InExpo }
                        NumberAnimation { property: "scale";   from: 1.0; to: 1.02; duration: 300; easing.type: Easing.InExpo }
                    }
                }
            }
        }
    }

    // ── Widget switching ───────────────────────────────────────────────────
    function switchWidget(newWidget, arg) {
        let involvesThemePicker = (newWidget === "theme" || currentActive === "theme");
        masterWindow.isWallpaperTransition = involvesThemePicker;

        if (newWidget === "hidden") {
            if (currentActive !== "hidden" && getLayout(currentActive)) {
                masterWindow.morphDuration = 250;
                masterWindow.disableMorph  = false;
                masterWindow.animW    = 1;
                masterWindow.animH    = 1;
                masterWindow.isVisible = false;
                delayedClear.start();
            }
        } else {
            if (currentActive === "hidden") {
                masterWindow.morphDuration = 250;
                masterWindow.disableMorph  = true;  // geen groei-animatie; alleen opacity
                prepTimer.newWidget   = newWidget;
                prepTimer.newArg      = arg;
                prepTimer.start();
            } else {
                masterWindow.morphDuration = 500;
                if (involvesThemePicker) {
                    masterWindow.disableMorph  = true;
                    masterWindow.isVisible     = false;
                    teleportFadeOutTimer.newWidget = newWidget;
                    teleportFadeOutTimer.newArg    = arg;
                    teleportFadeOutTimer.start();
                } else {
                    masterWindow.disableMorph = false;
                    executeSwitch(newWidget, arg, false);
                }
            }
        }
    }

    Timer {
        id: prepTimer
        interval: 50
        property string newWidget: ""
        property string newArg: ""
        onTriggered: executeSwitch(newWidget, newArg, false)
    }

    Timer {
        id: teleportFadeOutTimer
        interval: 150
        property string newWidget: ""
        property string newArg: ""
        onTriggered: {
            let t = getLayout(newWidget);
            masterWindow.currentActive = newWidget;
            masterWindow.activeArg     = newArg;
            masterWindow.animW         = t.w;
            masterWindow.animH         = t.h;
            masterWindow.currentX      = t.x;
            masterWindow.currentY      = t.y;
            widgetStack.replace(t.comp, {}, StackView.Immediate);
            teleportFadeInTimer.start();
        }
    }

    Timer {
        id: teleportFadeInTimer
        interval: 50
        onTriggered: {
            masterWindow.isVisible = true;
            resetMorphTimer.start();
        }
    }

    Timer {
        id: resetMorphTimer
        interval: masterWindow.morphDuration
        onTriggered: masterWindow.disableMorph = false
    }

    function executeSwitch(newWidget, arg, immediate) {
        masterWindow.currentActive = newWidget;
        masterWindow.activeArg     = arg;
        let t = getLayout(newWidget);
        masterWindow.animW    = t.w;
        masterWindow.animH    = t.h;
        masterWindow.currentX = t.x;
        masterWindow.currentY = t.y;
        masterWindow.isVisible = true;
        if (immediate) {
            widgetStack.replace(t.comp, {}, StackView.Immediate);
        } else {
            widgetStack.replace(t.comp, {});
        }
    }

    property string lastStateCommand: ""

    function handleStateCommand(rawCmd) {
        rawCmd = (rawCmd || "").trim();
        if (!rawCmd || rawCmd === masterWindow.lastStateCommand) return;
        masterWindow.lastStateCommand = rawCmd;

        let parts = rawCmd.split(":");
        let cmd   = parts[0];
        let arg   = parts.length > 1 ? parts[1] : "";

        if (parts.length >= 6) {
            masterWindow.activeMx = parseInt(parts[2]) || 0;
            masterWindow.activeMy = parseInt(parts[3]) || 0;
            masterWindow.activeMw = parseInt(parts[4]) || 1920;
            masterWindow.activeMh = parseInt(parts[5]) || 1080;
        } else {
            masterWindow.syncFocusedMonitorBounds();
        }

        if (cmd === "close") {
            switchWidget("hidden", "");
        } else if (getLayout(cmd)) {
            delayedClear.stop();
            if (masterWindow.isVisible && masterWindow.currentActive === cmd) {
                switchWidget("hidden", "");
            } else {
                switchWidget(cmd, arg);
            }
        }
    }

    // ── Widget state file watcher (QS 0.3.0: IPC met parameters werkt niet) ─
    FileView {
        path: "/tmp/qs_widget_state"
        watchChanges: true
        preload: true
        onInternalTextChanged: {
            masterWindow.handleStateCommand(__text || "");
        }
    }

    Process {
        id: statePoller
        command: ["bash", "-lc", "cat /tmp/qs_widget_state 2>/dev/null || true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                masterWindow.handleStateCommand(this.text || "");
            }
        }
    }

    // Some setups miss QFileSystemWatcher updates for this tmpfs-backed IPC file.
    // Keep FileView as the fast path, and use a low-frequency poll as fallback.
    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: if (!statePoller.running) statePoller.running = true
    }

    Timer {
        id: delayedClear
        interval: masterWindow.isWallpaperTransition ? 150 : masterWindow.morphDuration
        onTriggered: {
            masterWindow.currentActive = "hidden";
            widgetStack.clear();
            masterWindow.disableMorph  = false;
        }
    }
}
