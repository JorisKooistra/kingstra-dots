import QtQuick

// ── BotanicalGlow ─────────────────────────────────────────────────────────────
// Warme gloed over de bar: geel (boven) → perzik (midden) → groen (onder).
// Aan/uit via BotanicalBar.qml:  showWarmGlow: true/false
// Sterkte via BotanicalBar.qml:  warmGlowAlpha: 0.04   (hogere waarde = feller)
// ─────────────────────────────────────────────────────────────────────────────
Rectangle {
    required property var shell    // voor shell.s() schaling
    required property var mocha    // kleurenpalet
    required property var surface  // barSurfaceRoot — heeft skinBool/skinNumber/continuousBarMode

    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    height: surface.continuousBarMode ? surface.continuousRailHeight : parent.height
    z: 0.1
    visible: surface.isBotanical && surface.skinBool("showWarmGlow", false)
    opacity: surface.skinNumber("warmGlowAlpha", 0.04)

    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 1.0) }
        GradientStop { position: 0.5; color: Qt.rgba(mocha.peach.r,  mocha.peach.g,  mocha.peach.b,  0.4) }
        GradientStop { position: 1.0; color: Qt.rgba(mocha.green.r,  mocha.green.g,  mocha.green.b,  0.6) }
    }
}
