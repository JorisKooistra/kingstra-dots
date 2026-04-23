import QtQuick
import "../.."  // ThemeConfig — voor ThemeConfig.duration()

// ── CyberGrid ─────────────────────────────────────────────────────────────────
// Rasteroverlay voor het Cyber-theme. Bestaat uit zes sub-lagen (van onder naar boven):
//
//   1. Achtergrondgloed   — donkerblauw verloop (saffier → blauw, verticaal)
//   2. Donkere base       — halftransparante crust-kleur achter het grid
//   3. Verticale lijnen   — blauw, elke 22px, elke 4e lijn helderder
//   4. Horizontale lijnen — teal, elke 20px
//   5. Bovenste randlijn  — dunne teal lijn bovenaan
//   6. Onderste randlijn  — iets dikkere blauwe lijn onderaan
//   7. Sweep-licht        — teal gloed die van links naar rechts trekt
//
// Aan/uit via CyberBar.qml:  showCyberGrid: true/false
// Sterkte via CyberBar.qml:  gridAlpha: 0.38  (hogere waarde = feller grid)
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root
    required property var shell
    required property var mocha
    required property var surface

    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    height: surface.continuousBarMode ? surface.continuousRailHeight : parent.height
    z: 0.5
    visible: surface.ambientEnabled("cyber-grid", "cyber") && surface.skinBool("showCyberGrid", false)
    clip: true

    // ── 1. Achtergrondgloed ───────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        opacity: Math.max(0.0, Math.min(0.26,
            surface.effectAlpha(surface.skinNumber("gridAlpha", 0.0))
            * ((surface.activeTheme === "cyber") ? 0.9 : 0.35)))
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(mocha.sapphire.r, mocha.sapphire.g, mocha.sapphire.b, 0.55) }
            GradientStop { position: 1.0; color: Qt.rgba(mocha.blue.r,     mocha.blue.g,     mocha.blue.b,     0.15) }
        }
    }

    // ── 2. Donkere base ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b,
            Math.max(0.0, Math.min(0.34,
                surface.effectAlpha(surface.skinNumber("gridAlpha", 0.0))
                * ((surface.activeTheme === "cyber") ? 0.52 : 0.18))))
    }

    // ── 3. Verticale gridlijnen ───────────────────────────────────────────────
    Repeater {
        model: Math.ceil(root.width / shell.s(18))
        Rectangle {
            width: (index % 6) === 0 ? 2 : 1; height: parent.height; x: index * shell.s(18)
            color: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b,
                Math.max(0.0, Math.min(0.42,
                    surface.effectAlpha(surface.skinNumber("gridAlpha", 0.0))
                    * ((surface.activeTheme === "cyber") ? 1.7 : 1.0)
                    * ((index % 6) === 0 ? 0.90 : 0.30))))
        }
    }

    // ── 4. Horizontale gridlijnen ─────────────────────────────────────────────
    Repeater {
        model: Math.ceil(parent.height / shell.s(10))
        Rectangle {
            width: root.width; height: 1; y: index * shell.s(10)
            color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b,
                Math.max(0.0, Math.min(0.34,
                    surface.effectAlpha(surface.skinNumber("gridAlpha", 0.0))
                    * ((surface.activeTheme === "cyber") ? 1.7 : 1.0)
                    * ((index % 3) === 0 ? 0.62 : 0.24))))
        }
    }

    Repeater {
        model: Math.ceil(root.width / shell.s(64))
        Rectangle {
            x: index * shell.s(64) + shell.s(8)
            y: root.height - shell.s(5)
            width: shell.s(24)
            height: shell.s(2)
            color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b,
                Math.max(0.0, Math.min(0.72, surface.effectAlpha(surface.skinNumber("gridAlpha", 0.0)))))
        }
    }

    // ── 5. Bovenste randlijn ──────────────────────────────────────────────────
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 1
        color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b,
            Math.max(0.0, Math.min(0.28,
                surface.effectAlpha(surface.skinNumber("gridAlpha", 0.0))
                * ((surface.activeTheme === "cyber") ? 1.7 : 1.0)
                * 0.85)))
    }

    // ── 6. Onderste accentlijn ────────────────────────────────────────────────
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: shell.s(2)
        color: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b,
            Math.max(0.0, Math.min(0.42,
                surface.effectAlpha(surface.skinNumber("gridAlpha", 0.0))
                * ((surface.activeTheme === "cyber") ? 1.7 : 1.0)
                * 1.05)))
    }

    // ── 7. Sweep-licht ────────────────────────────────────────────────────────
    // Smal teal-verlooprechthoek dat de volle breedte van links naar rechts rijdt.
    Rectangle {
        id: cyberSweep
        width: shell.s(120); height: parent.height; x: -width
        opacity: Math.max(0.0, Math.min(0.34,
            surface.effectAlpha(surface.skinNumber("gridAlpha", 0.0))
            * ((surface.activeTheme === "cyber") ? 1.8 : 1.0)
            * 0.55))
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 1.0) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        SequentialAnimation on x {
            running: surface.skinBool("showCyberGrid", false); loops: Animation.Infinite
            NumberAnimation { to: parent.width; duration: ThemeConfig.duration(surface.effectCycleMs(5200)); easing.type: Easing.Linear }
            NumberAnimation { to: -cyberSweep.width; duration: 0 }  // reset zonder animatie
        }
    }
}
