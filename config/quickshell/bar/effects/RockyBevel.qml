import QtQuick

// ── RockyBevel ────────────────────────────────────────────────────────────────
// Twee dunne lijnen die een gebeiteld effect geven:
//   - bovenrand: licht (wit, halftransparant) → lijkt op lichtval van boven
//   - onderrand: donker (zwart, halftransparant) → slagschaduw
// Aan/uit via RockyBar.qml:  showBevelHighlight: true/false
// Sterkte via RockyBar.qml:  bevelLightAlpha: 0.12  (bovenrand)
//                             bevelDarkAlpha:  0.18  (onderrand)
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root
    required property var shell
    required property var mocha
    required property var surface

    anchors.fill: parent
    z: 0.6
    visible: surface.ambientEnabled("rocky-bevel", "rocky") && surface.skinBool("showBevelHighlight", false)

    Repeater {
        model: Math.ceil(root.width / shell.s(32))
        Rectangle {
            x: index * shell.s(32)
            y: 0
            width: 1
            height: root.height
            opacity: surface.effectAlpha((index % 2) === 0 ? 0.12 : 0.07)
            color: (index % 2) === 0 ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1)
        }
    }

    // Lichte bovenrand
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: shell.s(3)
        color: Qt.rgba(1, 1, 1, surface.effectAlpha(surface.skinNumber("bevelLightAlpha", 0.12)))
    }

    // Donkere onderrand
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: shell.s(4)
        color: Qt.rgba(0, 0, 0, surface.effectAlpha(surface.skinNumber("bevelDarkAlpha", 0.18)))
    }
}
