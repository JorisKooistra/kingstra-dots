import QtQuick

// ── SpaceNebula ───────────────────────────────────────────────────────────────
// Mauve-blauw-roze horizontaal kleurverloop dat een nevelachtige gloed geeft.
// Aan/uit via SpaceBar.qml:  showNebulaGlow: true/false
// Sterkte via SpaceBar.qml:  nebulaAlpha: 0.06  (hogere waarde = feller)
// ─────────────────────────────────────────────────────────────────────────────
Rectangle {
    required property var shell
    required property var mocha
    required property var surface

    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    height: surface.continuousBarMode ? surface.continuousRailHeight : parent.height
    z: 0.1
    visible: surface.isSpace && surface.skinBool("showNebulaGlow", false)
    opacity: surface.skinNumber("nebulaAlpha", 0.06)

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 1.0) }
        GradientStop { position: 0.5; color: Qt.rgba(mocha.blue.r,  mocha.blue.g,  mocha.blue.b,  0.5) }
        GradientStop { position: 1.0; color: Qt.rgba(mocha.pink.r,  mocha.pink.g,  mocha.pink.b,  1.0) }
    }
}
