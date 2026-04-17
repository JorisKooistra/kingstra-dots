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
    required property var shell
    required property var mocha
    required property var surface

    anchors.fill: parent
    z: 0.6
    visible: surface.isRocky && surface.skinBool("showBevelHighlight", false)

    // Lichte bovenrand
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 2
        color: Qt.rgba(1, 1, 1, surface.skinNumber("bevelLightAlpha", 0.12))
    }

    // Donkere onderrand
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 2
        color: Qt.rgba(0, 0, 0, surface.skinNumber("bevelDarkAlpha", 0.18))
    }
}
