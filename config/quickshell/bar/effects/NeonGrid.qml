import QtQuick
import "../.."  // ThemeConfig — voor ThemeConfig.duration()

// ── NeonGrid ──────────────────────────────────────────────────────────────────
// Rasteroverlay voor het Neon-theme. Bestaat uit meerdere sub-lagen:
//
//   1. Achtergrondgloed   — donkerblauw verloop (saffier → blauw, verticaal)
//   2. Donkere base       — halftransparante crust-kleur achter het grid
//   3. Verticale lijnen   — blauw, elke 22px, elke 4e lijn helderder
//   4. Horizontale lijnen — teal, elke 20px
//   5. Bovenste randlijn  — dunne teal lijn bovenaan
//   6. Onderste randlijn  — iets dikkere blauwe lijn onderaan
//   7. Sweep-licht        — teal gloed die van links naar rechts trekt
//
// Aan/uit via NeonBar.qml:  showNeonGrid: true/false
// Sterkte via NeonBar.qml:  gridAlpha: 0.38  (hogere waarde = feller grid)
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root
    required property var shell
    required property var mocha
    required property var surface

    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    height: surface.continuousBarMode ? surface.continuousRailHeight : parent.height
    z: 0.5
    visible: (surface.ambientEnabled("neon-grid", "neon") || surface.ambientEnabled("cyber-grid", "neon"))
             && surface.skinBool("showNeonGrid", false)
    clip: true

    function roleColor(name, fallbackColor) {
        return mocha[name] !== undefined ? mocha[name] : fallbackColor;
    }

    readonly property color neonPrimary: roleColor(surface.accentColorName, mocha.mauve)
    readonly property color neonHot: roleColor(surface.accentHotColorName, mocha.teal)
    readonly property color neonSignal: roleColor(surface.textHotColorName, mocha.pink)
    readonly property real gridStrength: surface.effectAlpha(surface.skinNumber("gridAlpha", 0.0))
    readonly property real laneStrength: surface.effectAlpha(surface.skinNumber("neonLaneAlpha", 0.0))
    readonly property real nodeStrength: surface.effectAlpha(surface.skinNumber("neonNodeAlpha", 0.0))
    readonly property bool continuousMotion: ThemeConfig.continuousEffects
        && ThemeConfig.effectIntensity > 0.0

    // ── 1. Achtergrondgloed ───────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        opacity: Math.max(0.0, Math.min(0.26,
            root.gridStrength * ((surface.activeTheme === "neon") ? 1.15 : 0.35)))
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(root.neonHot.r,     root.neonHot.g,     root.neonHot.b,     0.62) }
            GradientStop { position: 0.52; color: Qt.rgba(root.neonPrimary.r, root.neonPrimary.g, root.neonPrimary.b, 0.24) }
            GradientStop { position: 1.0; color: Qt.rgba(root.neonSignal.r,  root.neonSignal.g,  root.neonSignal.b,  0.18) }
        }
    }

    // ── 2. Donkere base ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b,
            Math.max(0.0, Math.min(0.34,
                root.gridStrength * ((surface.activeTheme === "neon") ? 0.56 : 0.18))))
    }

    // ── 3. Verticale gridlijnen ───────────────────────────────────────────────
    Repeater {
        model: Math.ceil(root.width / shell.s(18))
        Rectangle {
            width: (index % 6) === 0 ? 2 : 1; height: parent.height; x: index * shell.s(18)
            color: Qt.rgba(root.neonPrimary.r, root.neonPrimary.g, root.neonPrimary.b,
                Math.max(0.0, Math.min(0.42,
                    root.gridStrength * ((surface.activeTheme === "neon") ? 1.95 : 1.0)
                    * ((index % 6) === 0 ? 0.90 : 0.30))))
        }
    }

    // ── 4. Horizontale gridlijnen ─────────────────────────────────────────────
    Repeater {
        model: Math.ceil(parent.height / shell.s(10))
        Rectangle {
            width: root.width; height: 1; y: index * shell.s(10)
            color: Qt.rgba(root.neonHot.r, root.neonHot.g, root.neonHot.b,
                Math.max(0.0, Math.min(0.34,
                    root.gridStrength * ((surface.activeTheme === "neon") ? 1.95 : 1.0)
                    * ((index % 3) === 0 ? 0.62 : 0.24))))
        }
    }

    // ── 4b. Diagonale neon-lanes ─────────────────────────────────────────────
    Repeater {
        model: Math.ceil(root.width / shell.s(116))
        Rectangle {
            x: index * shell.s(116) - shell.s(48)
            y: -shell.s(8)
            width: shell.s(72)
            height: shell.s(2)
            rotation: -18
            transformOrigin: Item.Left
            color: Qt.rgba(root.neonSignal.r, root.neonSignal.g, root.neonSignal.b,
                Math.max(0.0, Math.min(0.56, root.laneStrength * ((index % 2) === 0 ? 0.70 : 0.38))))
        }
    }

    Repeater {
        model: Math.ceil(root.width / shell.s(140))
        Rectangle {
            x: index * shell.s(140) + shell.s(24)
            y: root.height - shell.s(8)
            width: shell.s(94)
            height: shell.s(2)
            rotation: 12
            transformOrigin: Item.Left
            color: Qt.rgba(root.neonHot.r, root.neonHot.g, root.neonHot.b,
                Math.max(0.0, Math.min(0.50, root.laneStrength * ((index % 2) === 0 ? 0.62 : 0.32))))
        }
    }

    Repeater {
        model: Math.ceil(root.width / shell.s(64))
        Rectangle {
            x: index * shell.s(64) + shell.s(8)
            y: root.height - shell.s(5)
            width: shell.s(24)
            height: shell.s(2)
            color: Qt.rgba(root.neonHot.r, root.neonHot.g, root.neonHot.b,
                Math.max(0.0, Math.min(0.78, root.gridStrength)))
        }
    }

    // ── 4c. Signaalnodes ─────────────────────────────────────────────────────
    Repeater {
        model: Math.ceil(root.width / shell.s(78))
        Rectangle {
            x: index * shell.s(78) + shell.s(15)
            y: ((index * 17) % Math.max(1, Math.round(root.height - shell.s(10)))) + shell.s(4)
            width: (index % 5) === 0 ? shell.s(5) : shell.s(3)
            height: width
            radius: width / 2
            color: Qt.rgba((index % 3) === 0 ? root.neonSignal.r : root.neonHot.r,
                           (index % 3) === 0 ? root.neonSignal.g : root.neonHot.g,
                           (index % 3) === 0 ? root.neonSignal.b : root.neonHot.b,
                           Math.max(0.0, Math.min(0.78, root.nodeStrength * ((index % 5) === 0 ? 0.9 : 0.55))))
        }
    }

    // ── 5. Bovenste randlijn ──────────────────────────────────────────────────
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 1
        color: Qt.rgba(root.neonHot.r, root.neonHot.g, root.neonHot.b,
            Math.max(0.0, Math.min(0.28,
                root.gridStrength * ((surface.activeTheme === "neon") ? 1.95 : 1.0)
                * 0.85)))
    }

    // ── 6. Onderste accentlijn ────────────────────────────────────────────────
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: shell.s(2)
        color: Qt.rgba(root.neonPrimary.r, root.neonPrimary.g, root.neonPrimary.b,
            Math.max(0.0, Math.min(0.42,
                root.gridStrength * ((surface.activeTheme === "neon") ? 1.95 : 1.0)
                * 1.05)))
    }

    // ── 7. Sweep-licht ────────────────────────────────────────────────────────
    // Smal teal-verlooprechthoek dat de volle breedte van links naar rechts rijdt.
    Rectangle {
        id: neonSweep
        width: shell.s(120); height: parent.height; x: -width
        opacity: Math.max(0.0, Math.min(0.34,
            root.gridStrength * ((surface.activeTheme === "neon") ? 2.0 : 1.0) * 0.62))
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.45; color: Qt.rgba(root.neonHot.r, root.neonHot.g, root.neonHot.b, 0.92) }
            GradientStop { position: 0.55; color: Qt.rgba(root.neonSignal.r, root.neonSignal.g, root.neonSignal.b, 0.80) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        SequentialAnimation on x {
            running: root.continuousMotion && surface.skinBool("showNeonGrid", false); loops: Animation.Infinite
            NumberAnimation { to: parent.width; duration: ThemeConfig.duration(surface.effectCycleMs(5200)); easing.type: Easing.Linear }
            NumberAnimation { to: -neonSweep.width; duration: 0 }  // reset zonder animatie
        }
    }
}
