import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../common/functions/HyprDispatch.js" as HyprDispatch
import "../../common"
import "../../common/kingstra"
import "../../services"
import "."

Scope {
    id: overviewScope
    Variants {
        id: overviewVariants
        model: Quickshell.screens
        PanelWindow {
            id: root
            required property var modelData
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
            property bool blurEnabled: Config.options.overview.effects.enableBlur
            property bool backdropEnabled: Config.options.overview.effects.enableBackdrop
            property real backdropOpacity: Math.max(0, Math.min(1, Config.options.overview.effects.backdropOpacity))
            // Alleen op het scherm dat de focus had bij het openen.
            readonly property bool isTargetScreen: GlobalStates.overviewScreenName === ""
                || GlobalStates.overviewScreenName === (monitor?.name ?? "")
            // 0 → 1 bij openen, 1 → 0 bij sluiten; het venster blijft zichtbaar
            // tot de uitfade klaar is.
            property real reveal: GlobalStates.overviewOpen && isTargetScreen ? 1 : 0
            Behavior on reveal {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.OutCubic
                }
            }
            screen: modelData
            visible: isTargetScreen && (GlobalStates.overviewOpen || reveal > 0)

            WlrLayershell.namespace: blurEnabled ? "quickshell:overview-blur" : "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.overviewOpen && isTargetScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            HyprlandFocusGrab {
                id: grab
                windows: [root]
                property bool canBeActive: root.monitorIsFocused
                active: false
                onCleared: () => {
                    if (!active)
                        GlobalStates.overviewOpen = false;
                }
            }

            Connections {
                target: GlobalStates
                function onOverviewOpenChanged() {
                    if (GlobalStates.overviewOpen && root.isTargetScreen) {
                        delayedGrabTimer.start();
                    }
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: Config.options.hacks.arbitraryRaceConditionDelay
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive)
                        return;
                    grab.active = GlobalStates.overviewOpen;
                }
            }

            // Keep the layershell surface full-screen so backdrop/blur are not constrained by content size.
            implicitWidth: screen.width
            implicitHeight: screen.height

            Item {
                id: keyHandler
                anchors.fill: parent
                focus: GlobalStates.overviewOpen
                z: 0

                Rectangle {
                    id: backdropLayer
                    anchors.fill: parent
                    visible: root.backdropEnabled
                    color: "#000000"
                    opacity: root.backdropOpacity * root.reveal
                    z: 0
                }

                // Sluiten zonder toetsenbord: klik op een lege plek, rechtsklik of
                // een extra muisknop (bv. de M720-duimknop) sluit het overzicht.
                // Werkruimtes en vensters accepteren alleen links/midden, dus
                // andere knoppen vallen hier altijd doorheen.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    z: 0
                    enabled: GlobalStates.overviewOpen
                    onClicked: GlobalStates.overviewOpen = false
                }

                Keys.onPressed: event => {
                    // close: Escape or Enter
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return) {
                        GlobalStates.overviewOpen = false;
                        event.accepted = true;
                        return;
                    }

                    // Helper: compute current group bounds
                    const workspacesPerGroup = Config.options.overview.rows * Config.options.overview.columns;
                    const currentId = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
                    const useWorkspaceMap = Config.options.overview.useWorkspaceMap;
                    const workspaceMap = Config.options.overview.workspaceMap ?? [];
                    const focusedMonitorId = Hyprland.focusedMonitor?.id ?? root.monitor?.id ?? 0;
                    const workspaceOffset = useWorkspaceMap ? Number(workspaceMap[focusedMonitorId] ?? 0) : 0;
                    const currentGroup = Math.floor((currentId - workspaceOffset - 1) / workspacesPerGroup);
                    const minWorkspaceId = currentGroup * workspacesPerGroup + 1 + workspaceOffset;
                    const maxWorkspaceId = minWorkspaceId + workspacesPerGroup - 1;

                    const rows = Config.options.overview.rows;
                    const columns = Config.options.overview.columns;
                    const reverseColumns = Config.options.overview.orderRightLeft;
                    const reverseRows = Config.options.overview.orderBottomUp;

                    const clampedIndex = Math.max(0, Math.min(workspacesPerGroup - 1, currentId - minWorkspaceId));
                    const currentNormalRow = Math.floor(clampedIndex / columns);
                    const currentNormalColumn = clampedIndex % columns;

                    function toVisualRow(normalRow) {
                        return reverseRows ? (rows - normalRow - 1) : normalRow;
                    }

                    function toVisualColumn(normalColumn) {
                        return reverseColumns ? (columns - normalColumn - 1) : normalColumn;
                    }

                    function toNormalRow(visualRow) {
                        return reverseRows ? (rows - visualRow - 1) : visualRow;
                    }

                    function toNormalColumn(visualColumn) {
                        return reverseColumns ? (columns - visualColumn - 1) : visualColumn;
                    }

                    let targetVisualRow = toVisualRow(currentNormalRow);
                    let targetVisualColumn = toVisualColumn(currentNormalColumn);

                    let targetId = null;

                    // Arrow keys and vim-style hjkl
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        targetVisualColumn = (targetVisualColumn - 1 + columns) % columns;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        targetVisualColumn = (targetVisualColumn + 1) % columns;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        targetVisualRow = (targetVisualRow - 1 + rows) % rows;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        targetVisualRow = (targetVisualRow + 1) % rows;
                    }

                    // Number keys: jump to workspace within the current group
                    // 1-9 map to positions 1-9, 0 maps to position 10
                    else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        const position = event.key - Qt.Key_0; // 1-9
                        if (position <= workspacesPerGroup) {
                            targetId = minWorkspaceId + position - 1;
                        }
                    } else if (event.key === Qt.Key_0) {
                        // 0 = 10th workspace in the group (if group has 10+ workspaces)
                        if (workspacesPerGroup >= 10) {
                            targetId = minWorkspaceId + 9; // 10th position = offset 9
                        }
                    }

                    if (targetId === null && (
                        event.key === Qt.Key_Left || event.key === Qt.Key_H ||
                        event.key === Qt.Key_Right || event.key === Qt.Key_L ||
                        event.key === Qt.Key_Up || event.key === Qt.Key_K ||
                        event.key === Qt.Key_Down || event.key === Qt.Key_J
                    )) {
                        const targetNormalRow = toNormalRow(targetVisualRow);
                        const targetNormalColumn = toNormalColumn(targetVisualColumn);
                        targetId = minWorkspaceId + targetNormalRow * columns + targetNormalColumn;
                    }

                    if (targetId !== null) {
                        const clampedTarget = Math.max(minWorkspaceId, Math.min(maxWorkspaceId, targetId));
                        Hyprland.dispatch(HyprDispatch.workspace(clampedTarget));
                        event.accepted = true;
                    }
                }
            }

            ColumnLayout {
                id: columnLayout
                z: 1
                spacing: 6
                // Midden op het scherm: de grid staat altijd op dezelfde plek,
                // los van hoeveel ruimte de bar inneemt.
                anchors.centerIn: parent
                opacity: root.reveal
                scale: 0.96 + 0.04 * root.reveal
                transformOrigin: Item.Center

                // Zelfde kop als de werkvlak-kaart.
                OverviewHeader {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 4
                    look: Appearance.look
                    heading: "Werkruimten"
                    hint: "Klik kiest  ·  sleep een venster  ·  rechtsklik of Esc sluit"
                }

                Loader {
                    id: overviewLoader
                    active: root.visible && (Config?.options.overview.enable ?? true)
                    sourceComponent: OverviewWidget {
                        panelWindow: root
                        visible: true
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "overview"

        function rememberScreen() {
            GlobalStates.overviewScreenName = Hyprland.focusedMonitor?.name ?? "";
        }
        function toggle() {
            if (!GlobalStates.overviewOpen)
                rememberScreen();
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            rememberScreen();
            GlobalStates.overviewOpen = true;
        }
    }
}
