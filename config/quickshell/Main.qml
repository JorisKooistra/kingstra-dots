import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "WindowRegistry.js" as Registry

FloatingWindow {
    id: masterWindow
    title: "qs-master"
    color: "transparent"
    
    // Always mapped to prevent Wayland from destroying the surface and Hyprland from auto-centering!
    visible: true 

    property string hiddenWorkspaceName: "special:qs-master"

    // Push it to the secret workspace the moment the component loads
    Component.onCompleted: {
        moveToHiddenWorkspace();
    }

    // -------------------------------------------------------------------------
    // WAYLAND WORKSPACE MANAGEMENT
    // -------------------------------------------------------------------------
    function moveToHiddenWorkspace() {
        Quickshell.execDetached([
            "bash",
            "-c",
            `hyprctl --batch "dispatch movetoworkspacesilent ${masterWindow.hiddenWorkspaceName},title:^(qs-master)$ ; dispatch resizewindowpixel exact 1 1,title:^(qs-master)$"`
        ]);
    }

    function placeOnActiveWorkspace(x, y, w, h, focusAfter) {
        let focusDispatch = focusAfter ? " ; dispatch focuswindow title:^(qs-master)$" : "";
        Quickshell.execDetached([
            "bash",
            "-c",
            `ws="$(hyprctl activeworkspace -j | jq -r '.name // "1"')"; hyprctl --batch "dispatch movetoworkspacesilent $ws,title:^(qs-master)$ ; dispatch resizewindowpixel exact ${w} ${h},title:^(qs-master)$ ; dispatch movewindowpixel exact ${x} ${y},title:^(qs-master)$${focusDispatch}"`
        ]);
    }

    // Dynamic monitor tracking
    property int activeMx: 0
    property int activeMy: 0
    property int activeMw: 1920
    property int activeMh: 1080

    // --- SELF-HEALING GEOMETRY ---
    // Automatically resizes the physical Hyprland window if the OS resolution changes while open
    Connections {
        target: Screen
        function onWidthChanged() { handleNativeScreenChange(); }
        function onHeightChanged() { handleNativeScreenChange(); }
    }

    function handleNativeScreenChange() {
        if (masterWindow.currentActive === "hidden") return;
        
        // 1. Instant pre-emptive UI resize to prevent clipping (0ms delay)
        masterWindow.activeMw = Screen.width;
        masterWindow.activeMh = Screen.height;
        
        let t = getLayout(masterWindow.currentActive);
        if (t) {
            masterWindow.animW = t.w;
            masterWindow.animH = t.h;
            masterWindow.width = t.w;
            masterWindow.height = t.h;
            // It's already on the active workspace, so just resize it
            Quickshell.execDetached(["bash", "-c", `hyprctl dispatch resizewindowpixel "exact ${t.w} ${t.h},title:^(qs-master)$"`]);
        }
        
        // 2. Fetch absolute truth from Hyprland to fix X/Y offsets asynchronously
        updatePhysicalBounds.running = true;
    }

    Process {
        id: updatePhysicalBounds
        command: ["bash", "-c", "hyprctl monitors -j | jq -r '.[] | select(.focused==true) | \"\\(.x):\\(.y):\\((.width / (.scale // 1)) | round):\\((.height / (.scale // 1)) | round)\"'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split(":");
                if (parts.length === 4 && masterWindow.currentActive !== "hidden") {
                    masterWindow.activeMx = parseInt(parts[0]) || 0;
                    masterWindow.activeMy = parseInt(parts[1]) || 0;
                    masterWindow.activeMw = parseInt(parts[2]) || 1920;
                    masterWindow.activeMh = parseInt(parts[3]) || 1080;

                    let t = getLayout(masterWindow.currentActive);
                    if (t) {
                        masterWindow.currentX = t.x;
                        masterWindow.currentY = t.y;
                        Quickshell.execDetached(["bash", "-c", `hyprctl dispatch movewindowpixel "exact ${t.x} ${t.y},title:^(qs-master)$"`]);
                    }
                }
            }
        }
    }
    // -----------------------------

    property string currentActive: "hidden" 
    onCurrentActiveChanged: {
        Quickshell.execDetached(["bash", "-c", "echo '" + currentActive + "' > /tmp/qs_active_widget"]);
    }

    property bool isVisible: false
    property string activeArg: ""
    property bool disableMorph: false 
    property bool isWallpaperTransition: false 

    // Dynamic duration to allow fast opening but keep morphing smooth
    property int morphDuration: 500

    property int currentX: 0
    property int currentY: 0

    property real animW: 1
    property real animH: 1

    function getLayout(name) {
        return Registry.getLayout(name, masterWindow.activeMx, masterWindow.activeMy, masterWindow.activeMw, masterWindow.activeMh);
    }
    
    width: 1
    height: 1
    implicitWidth: width
    implicitHeight: height

    onIsVisibleChanged: {
        if (isVisible) masterWindow.requestActivate();
    }

    Item {
        anchors.centerIn: parent
        width: masterWindow.animW
        height: masterWindow.animH
        clip: true 

        Behavior on width { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutCubic } }

        opacity: masterWindow.isVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: masterWindow.isWallpaperTransition ? 150 : (masterWindow.morphDuration === 500 ? 300 : 200); easing.type: Easing.InOutSine } }

        // INNER FIXED CONTAINER
        Item {
            anchors.centerIn: parent
            width: masterWindow.currentActive !== "hidden" && getLayout(masterWindow.currentActive) ? getLayout(masterWindow.currentActive).w : 1
            height: masterWindow.currentActive !== "hidden" && getLayout(masterWindow.currentActive) ? getLayout(masterWindow.currentActive).h : 1

            StackView {
                id: widgetStack
                anchors.fill: parent
                focus: true
                
                Keys.onEscapePressed: {
                    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"])
                    event.accepted = true
                }

                onCurrentItemChanged: {
                    if (currentItem) currentItem.forceActiveFocus();
                }

                replaceEnter: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 400; easing.type: Easing.OutExpo }
                        NumberAnimation { property: "scale"; from: 0.98; to: 1.0; duration: 400; easing.type: Easing.OutBack }
                    }
                }
                replaceExit: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 300; easing.type: Easing.InExpo }
                        NumberAnimation { property: "scale"; from: 1.0; to: 1.02; duration: 300; easing.type: Easing.InExpo }
                    }
                }
            }
        }
    }

    function switchWidget(newWidget, arg) {
        let involvesWallpaper = (newWidget === "wallpaper" || currentActive === "wallpaper");
        masterWindow.isWallpaperTransition = involvesWallpaper;

        if (newWidget === "hidden") {
            if (currentActive !== "hidden" && getLayout(currentActive)) {
                masterWindow.morphDuration = 250; 
                masterWindow.disableMorph = false;
                let t = getLayout(currentActive);
                let cx = Math.floor(t.x + (t.w/2));
                let cy = Math.floor(t.y + (t.h/2));
                
                masterWindow.animW = 1;
                masterWindow.animH = 1;
                masterWindow.isVisible = false;
                
                // Keep it on the active workspace while shrinking for the animation
                placeOnActiveWorkspace(cx, cy, 1, 1, false);
                delayedClear.start();
            }
        } else {
            if (currentActive === "hidden") {
                masterWindow.morphDuration = 250; 
                masterWindow.disableMorph = false;
                let t = getLayout(newWidget);
                let cx = Math.floor(t.x + (t.w / 2));
                let cy = Math.floor(t.y + (t.h / 2));

                masterWindow.animW = 1;
                masterWindow.animH = 1;
                masterWindow.width = 1;
                masterWindow.height = 1;

                placeOnActiveWorkspace(cx, cy, 1, 1, false);

                prepTimer.newWidget = newWidget;
                prepTimer.newArg = arg;
                prepTimer.start();
                
            } else {
                masterWindow.morphDuration = 500; 
                if (involvesWallpaper) {
                    masterWindow.disableMorph = true;
                    masterWindow.isVisible = false; 
                    teleportFadeOutTimer.newWidget = newWidget;
                    teleportFadeOutTimer.newArg = arg;
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
            masterWindow.activeArg = newArg;

            masterWindow.animW = t.w;
            masterWindow.animH = t.h;
            masterWindow.width = t.w;
            masterWindow.height = t.h;
            masterWindow.currentX = t.x;
            masterWindow.currentY = t.y;

            placeOnActiveWorkspace(t.x, t.y, t.w, t.h, true);

            let props = newWidget === "wallpaper" ? { "widgetArg": newArg } : {};
            widgetStack.replace(t.comp, props, StackView.Immediate);

            teleportFadeInTimer.newWidget = newWidget;
            teleportFadeInTimer.newArg = newArg;
            teleportFadeInTimer.start();
        }
    }

    Timer {
        id: teleportFadeInTimer
        interval: 50 
        property string newWidget: ""
        property string newArg: ""
        onTriggered: {
            masterWindow.isVisible = true; 
            if (newWidget !== "wallpaper") resetMorphTimer.start();
        }
    }

    Timer {
        id: resetMorphTimer
        interval: masterWindow.morphDuration 
        onTriggered: masterWindow.disableMorph = false
    }

    function executeSwitch(newWidget, arg, immediate) {
        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;
        
        let t = getLayout(newWidget);
        masterWindow.animW = t.w;
        masterWindow.animH = t.h;
        masterWindow.width = t.w;
        masterWindow.height = t.h;
        masterWindow.currentX = t.x;
        masterWindow.currentY = t.y;
        
        placeOnActiveWorkspace(t.x, t.y, t.w, t.h, true);
        
        masterWindow.isVisible = true;
        
        let props = newWidget === "wallpaper" ? { "widgetArg": arg } : {};

        if (immediate) {
            widgetStack.replace(t.comp, props, StackView.Immediate);
        } else {
            widgetStack.replace(t.comp, props);
        }
    }

    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: { if (!ipcPoller.running) ipcPoller.running = true; }
    }

    Process {
        id: ipcPoller
        command: ["bash", "-c", "if [ -f /tmp/qs_widget_state ]; then cat /tmp/qs_widget_state; rm /tmp/qs_widget_state; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let rawCmd = this.text.trim();
                if (rawCmd === "") return;

                let parts = rawCmd.split(":");
                let cmd = parts[0];
                let arg = parts.length > 1 ? parts[1] : "";

                if (parts.length >= 6) {
                    masterWindow.activeMx = parseInt(parts[2]) || 0;
                    masterWindow.activeMy = parseInt(parts[3]) || 0;
                    masterWindow.activeMw = parseInt(parts[4]) || 1920;
                    masterWindow.activeMh = parseInt(parts[5]) || 1080;
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
        }
    }

    Timer {
        id: delayedClear
        interval: masterWindow.isWallpaperTransition ? 150 : masterWindow.morphDuration 
        onTriggered: {
            masterWindow.currentActive = "hidden";
            widgetStack.clear();
            masterWindow.disableMorph = false;
            
            // Banished safely back to the shadow workspace
            moveToHiddenWorkspace();
        }
    }
}
