import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Kingstra.Blobs 1.0
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

                // Drie lagen, in deze volgorde:
                //   z 0  — de omlijstings-blob, die naar binnen uitvloeit
                //   z 30 — de panelhost (paneelblob + inhoud)
                //   z 40 — de chrome met railvlak en knoppen
                // Zo smelt een paneel onderaan samen met de omlijsting, terwijl
                // het ondoorzichtige railvlak met de knoppen er altijd bovenop
                // ligt. Zat de omlijstings-blob in de chrome, dan tekende zijn
                // uitvloeiing als een balk over de linkerkant van elk paneel.
                BlobInvertedRect {
                    id: frameBlobLayer
                    z: 0
                    anchors.fill: parent
                    anchors.margins: -50
                    visible: chrome.cornersActive
                    group: chrome.edgeBlobGroup
                    radius: chrome.cornerR
                    borderLeft: chrome.railWidth - anchors.margins
                    borderRight: chrome.shellBorderWidth - anchors.margins
                    borderTop: chrome.stripHeight - anchors.margins
                    borderBottom: chrome.shellBorderWidth - anchors.margins
                }

                ShellChrome {
                    id: chrome
                    anchors.fill: parent
                    shellWindow: surfaceWindow
                    mocha: mocha
                    z: 40
                    // Uitgroeiende randpanelen worden als één edge-blob in de
                    // chrome opgenomen. De launcher is nu de eerste gebruiker.
                    edgeBlobOpen: panelHost.visualFromEdge && (panelHost.open || panelHost.width > 1 || panelHost.height > 1)
                    edgeBlobEdge: panelHost.visualEdge
                    edgeBlobProgress: panelHost.visualEdgeBlobProgress
                    edgeBlobX: panelHost.x
                    edgeBlobY: panelHost.y
                    edgeBlobWidth: panelHost.width
                    edgeBlobHeight: panelHost.height
                    onPanelRequested: (sourceEntryId, anchorX, anchorY) => {
                        topHoverCloseTimer.stop();
                        panelHost.anchorX = anchorX;
                        panelHost.anchorY = anchorY;
                        panelHost.sourceEntryId = sourceEntryId === "tophover"
                            ? sourceEntryId
                            : (panelHost.sourceEntryId === sourceEntryId ? "" : sourceEntryId);
                    }
                    onPanelCloseRequested: (sourceEntryId) => {
                        if (panelHost.sourceEntryId === sourceEntryId)
                            topHoverCloseTimer.restart();
                    }
                }

                // Klik-buiten-om-te-sluiten. De geometrie is bewust aan de
                // open-state gekoppeld i.p.v. alleen `visible`: de mask-Region
                // hieronder volgt de item-geometrie en niet de zichtbaarheid,
                // dus een fullscreen item dat "alleen maar onzichtbaar" is
                // blokkeert nog steeds elke muisklik op het hele scherm.
                // De laag spaart de rail en de strip uit: die houden hun eigen
                // hit-regions, zodat je met een open paneel meteen op een
                // andere bar-knop kunt klikken in plaats van eerst te moeten
                // sluiten. Alles daarbuiten dismisst.
                Item {
                    id: closeDismissLayer

                    readonly property int railInset: ThemeConfig.barRailEnabled
                        && ThemeConfig.barRailEdge === "left" ? chrome.railWidth : 0
                    readonly property int rightInset: ThemeConfig.barRailEnabled
                        && ThemeConfig.barRailEdge === "right" ? chrome.railWidth : 0
                    readonly property int topInset: ThemeConfig.barStatusStripEnabled
                        && ThemeConfig.barStatusStripEdge === "top" ? chrome.stripHeight : 0
                    readonly property int bottomInset: ThemeConfig.barStatusStripEnabled
                        && ThemeConfig.barStatusStripEdge === "bottom" ? chrome.stripHeight : 0

                    x: panelHost.open ? railInset : 0
                    y: panelHost.open ? topInset : 0
                    width: panelHost.open
                        ? Math.max(0, surfaceWindow.width - railInset - rightInset) : 0
                    height: panelHost.open
                        ? Math.max(0, surfaceWindow.height - topInset - bottomInset) : 0
                    visible: panelHost.open
                    z: 20

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        hoverEnabled: true
                        cursorShape: Qt.ArrowCursor
                        onClicked: {
                            topHoverCloseTimer.stop();
                            panelHost.sourceEntryId = "";
                        }
                    }
                }

                PanelHost {
                    id: panelHost
                    hostWindow: surfaceWindow
                    anchorItem: chrome
                    z: 30
                    onHoveredChanged: {
                        if (sourceEntryId === "tophover" && !hovered && !chrome.topHoverHovered)
                            topHoverCloseTimer.restart();
                    }
                }

                Timer {
                    id: topHoverCloseTimer
                    interval: 220
                    repeat: false
                    onTriggered: {
                        if (panelHost.sourceEntryId === "tophover"
                                && !panelHost.hovered
                                && !chrome.topHoverHovered)
                            panelHost.sourceEntryId = "";
                    }
                }

                // De state-file overleeft een shell-herstart. Zonder deze guard
                // leest FileView bij het opstarten de laatst geschreven widget
                // en opent die meteen weer — inclusief de fullscreen
                // dismiss-layer, wat het scherm onklikbaar maakt zonder dat er
                // zichtbaar iets openstaat. De eerste read is dus altijd alleen
                // een sync van de uitgangspositie.
                property bool widgetStatePrimed: false

                function handleWidgetState(rawState) {
                    if (!widgetStatePrimed) {
                        widgetStatePrimed = true;
                        return;
                    }
                    let target = String(rawState || "").trim().split(":")[0];
                    if (target === "close") {
                        panelHost.sourceEntryId = "";
                        return;
                    }
                    let surfaceTargets = ["battery", "focustime", "network", "volume", "music", "calendar", "monitors", "performance", "gaming", "settings", "power", "launcher", "tophover"];
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
                    Region { item: chrome.topHoverHitRegion }
                    Region { item: closeDismissLayer }
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
                    implicitHeight: chrome.stripHeight
                    color: "transparent"
                    mask: Region {}
                    WlrLayershell.namespace: "quickshell:kingstra-shell-strip-reservation"
                    WlrLayershell.layer: WlrLayer.Top
                    WlrLayershell.exclusiveZone: chrome.stripHeight
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                }

                // Dunne omlijning rechts/onder: alleen ruimte reserveren, het
                // tekenwerk zit in ShellChrome.
                PanelWindow {
                    screen: surfaceWindow.screen
                    visible: false
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
                    visible: false
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
