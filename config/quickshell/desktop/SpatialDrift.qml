import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"

// Klein wallpaper-effect bij het bewegen over het ruimtelijk werkvlak.
// skwd-paper kan de wallpaper zelf niet verschuiven, dus geen echte
// parallax: een zachte lichtvlek op de Bottom-laag (boven de wallpaper,
// onder de vensters) glijdt tegen de beweging in en dooft weer uit. Zo voelt
// het alsof je over de wallpaper beweegt. De Lua-layout meldt elke
// camerabeweging als custom>>kingstra-pan,<werkruimte>,<dx>,<dy>.
// Uit te zetten per scherm via Instellingen › Bediening.
Scope {
    id: root

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                screen: modelData

                readonly property bool allowed: ScreenProfiles.profile(modelData.name).wallpaperDrift
                // Alleen zichtbaar zolang het effect loopt; daarna geen oppervlak.
                visible: allowed && (drift.running || glow.opacity > 0.01)

                anchors { top: true; bottom: true; left: true; right: true }
                color: "transparent"
                mask: Region {}
                WlrLayershell.namespace: "quickshell:kingstra-spatial-drift"
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                MatugenColors { id: mocha }

                function nudge(dx, dy) {
                    // Hoogstens een achtste scherm, tegen de beweging in.
                    // Schermmaat, want het verborgen venster heeft nog geen grootte.
                    let w = modelData.width, h = modelData.height;
                    let sx = -Math.max(-1, Math.min(1, dx)) * w * 0.12;
                    let sy = -Math.max(-1, Math.min(1, dy)) * h * 0.12;
                    drift.stop();
                    glow.shiftX = Math.max(-w * 0.25, Math.min(w * 0.25, glow.shiftX + sx));
                    glow.shiftY = Math.max(-h * 0.25, Math.min(h * 0.25, glow.shiftY + sy));
                    drift.start();
                }

                Connections {
                    target: Hyprland
                    enabled: win.allowed
                    function onRawEvent(event) {
                        if (String(event?.name ?? "") !== "custom") return;
                        let parts = String(event?.data ?? "").split(",");
                        if (parts.length !== 4 || parts[0] !== "kingstra-pan") return;
                        let monitor = Hyprland.monitorFor(win.screen);
                        let active = monitor && monitor.activeWorkspace ? String(monitor.activeWorkspace.id) : "";
                        if (parts[1] !== active) return;
                        let dx = Number(parts[2]), dy = Number(parts[3]);
                        if (isFinite(dx) && isFinite(dy)) win.nudge(dx, dy);
                    }
                }

                Item {
                    id: glow
                    property real shiftX: 0
                    property real shiftY: 0
                    readonly property real blobSize: Math.max(win.width, win.height) * 0.9
                    anchors.fill: parent
                    opacity: 0

                    // Zachte lichtvlek in de accentkleur van het thema.
                    Shape {
                        width: glow.blobSize
                        height: glow.blobSize
                        x: (win.width - width) / 2 + glow.shiftX
                        y: (win.height - height) / 2 + glow.shiftY
                        ShapePath {
                            strokeColor: "transparent"
                            strokeWidth: 0
                            fillGradient: RadialGradient {
                                centerX: glow.blobSize / 2; centerY: glow.blobSize / 2
                                focalX: glow.blobSize / 2; focalY: glow.blobSize / 2
                                centerRadius: glow.blobSize / 2
                                GradientStop { position: 0.0; color: Qt.alpha(mocha.primary, 0.2) }
                                GradientStop { position: 0.5; color: Qt.alpha(mocha.primary, 0.06) }
                                GradientStop { position: 1.0; color: Qt.alpha(mocha.primary, 0) }
                            }
                            PathAngleArc {
                                centerX: glow.blobSize / 2; centerY: glow.blobSize / 2
                                radiusX: glow.blobSize / 2; radiusY: glow.blobSize / 2
                                startAngle: 0; sweepAngle: 360
                            }
                        }
                    }
                }

                ParallelAnimation {
                    id: drift
                    SequentialAnimation {
                        NumberAnimation { target: glow; property: "opacity"; to: 1; duration: ThemeConfig.duration(140); easing.type: Easing.OutCubic }
                        NumberAnimation { target: glow; property: "opacity"; to: 0; duration: ThemeConfig.duration(700); easing.type: Easing.InOutSine }
                    }
                    NumberAnimation { target: glow; property: "shiftX"; to: 0; duration: ThemeConfig.duration(840); easing.type: Easing.OutCubic }
                    NumberAnimation { target: glow; property: "shiftY"; to: 0; duration: ThemeConfig.duration(840); easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
