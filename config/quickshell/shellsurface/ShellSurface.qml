import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

// Per-screen foundation for the future rail, status strip, and panel host.
// Keep the spike transparent and input-transparent until a later phase owns
// explicit interactive regions.
Scope {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: surfaceWindow

                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                implicitWidth: screen ? screen.width : 0
                implicitHeight: screen ? screen.height : 0
                color: "transparent"

                MatugenColors { id: mocha }
                ShellChrome {
                    id: chrome
                    anchors.fill: parent
                    shellWindow: surfaceWindow
                    mocha: mocha
                    // De onderrand moet om de launcher heen buigen, dus de
                    // chrome heeft zijn positie en breedte nodig.
                    launcherOpen: panelHost.fromBottom && panelHost.open
                    launcherX: panelHost.x
                    launcherWidth: panelHost.panelWidth("launcher")
                    onPanelRequested: (sourceEntryId, anchorX, anchorY) => {
                        panelHost.anchorX = anchorX;
                        panelHost.anchorY = anchorY;
                        panelHost.sourceEntryId = panelHost.sourceEntryId === sourceEntryId ? "" : sourceEntryId;
                    }
                }
                PanelHost { id: panelHost; hostWindow: surfaceWindow; anchorItem: chrome }

                function handleWidgetState(rawState) {
                    let target = String(rawState || "").trim().split(":")[0];
                    if (target === "close") {
                        panelHost.sourceEntryId = "";
                        return;
                    }
                    let surfaceTargets = ["battery", "focustime", "network", "volume", "music", "calendar", "monitors", "performance", "gaming", "settings", "launcher"];
                    if (!ThemeConfig.barZoneSchemaLoaded || surfaceTargets.indexOf(target) === -1) return;
                    if (Hyprland.monitorFor(surfaceWindow.screen) === Hyprland.focusedMonitor)
                        panelHost.sourceEntryId = target;
                }

                // Zonder focusgrab levert OnDemand pas toetsenbordfocus ná een
                // klik, waardoor typen in de launcher niet aankwam. De grab
                // routeert input naar deze surface en sluit het paneel zodra
                // je ergens anders klikt.
                HyprlandFocusGrab {
                    active: panelHost.open && panelHost.needsKeyboard
                    windows: [surfaceWindow]
                    onCleared: panelHost.sourceEntryId = ""
                }

                FileView {
                    id: widgetStateView
                    path: "/tmp/qs_widget_state"
                    watchChanges: true
                    preload: true
                    onInternalTextChanged: surfaceWindow.handleWidgetState(__text)
                }
                Timer {
                    interval: 400
                    running: true
                    repeat: true
                    onTriggered: widgetStateView.reload()
                }

                WlrLayershell.namespace: "quickshell:kingstra-shell-surface"
                WlrLayershell.layer: WlrLayer.Top
                // Cover the physical screen, independent of the legacy bar's
                // reservation, while reserving no space of its own.
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: panelHost.open
                    ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

                // Only the visible controls receive pointer events; the rest of
                // this full-screen host remains click-through.
                mask: Region {
                    Region { item: chrome.railHitRegion }
                    Region { item: chrome.stripHitRegion }
                    Region { item: panelHost }
                }

                // Reservation windows intentionally carry no content or input.
                // They let the single visual host reserve two independent edges.
                PanelWindow {
                    screen: surfaceWindow.screen
                    visible: ThemeConfig.barZoneSchemaLoaded && ThemeConfig.barRailEnabled
                    anchors.left: ThemeConfig.barRailEdge === "left"
                    anchors.right: ThemeConfig.barRailEdge === "right"
                    anchors.top: true
                    anchors.bottom: true
                    implicitWidth: ThemeConfig.barRailWidth
                    color: "transparent"
                    mask: Region {}
                    WlrLayershell.namespace: "quickshell:kingstra-shell-rail-reservation"
                    WlrLayershell.layer: WlrLayer.Top
                    WlrLayershell.exclusiveZone: ThemeConfig.barRailWidth
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                }

                PanelWindow {
                    screen: surfaceWindow.screen
                    visible: ThemeConfig.barZoneSchemaLoaded && ThemeConfig.barStatusStripEnabled
                    anchors.left: true
                    anchors.right: true
                    anchors.top: ThemeConfig.barStatusStripEdge === "top"
                    anchors.bottom: ThemeConfig.barStatusStripEdge === "bottom"
                    implicitHeight: ThemeConfig.barStatusStripHeight
                    color: "transparent"
                    mask: Region {}
                    WlrLayershell.namespace: "quickshell:kingstra-shell-strip-reservation"
                    WlrLayershell.layer: WlrLayer.Top
                    WlrLayershell.exclusiveZone: ThemeConfig.barStatusStripHeight
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                }

                // Dunne omlijning rechts/onder: alleen ruimte reserveren, het
                // tekenwerk zit in ShellChrome.
                PanelWindow {
                    screen: surfaceWindow.screen
                    visible: chrome.cornersActive
                    anchors.right: true
                    anchors.top: true
                    anchors.bottom: true
                    implicitWidth: chrome.shellBorderWidth
                    color: "transparent"
                    mask: Region {}
                    WlrLayershell.namespace: "quickshell:kingstra-shell-right-reservation"
                    WlrLayershell.layer: WlrLayer.Top
                    WlrLayershell.exclusiveZone: chrome.shellBorderWidth
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                }

                PanelWindow {
                    screen: surfaceWindow.screen
                    visible: chrome.cornersActive
                    anchors.left: true
                    anchors.right: true
                    anchors.bottom: true
                    implicitHeight: chrome.shellBorderWidth
                    color: "transparent"
                    mask: Region {}
                    WlrLayershell.namespace: "quickshell:kingstra-shell-bottom-reservation"
                    WlrLayershell.layer: WlrLayer.Top
                    WlrLayershell.exclusiveZone: chrome.shellBorderWidth
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                }
            }
        }
    }
}
