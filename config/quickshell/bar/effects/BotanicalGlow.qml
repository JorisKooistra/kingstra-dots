import QtQuick

// ── BotanicalGlow ─────────────────────────────────────────────────────────────
// Warme gloed over de bar: geel (boven) → perzik (midden) → groen (onder).
// Aan/uit via BotanicalBar.qml:  showWarmGlow: true/false
// Sterkte via BotanicalBar.qml:  warmGlowAlpha: 0.04   (hogere waarde = feller)
// ─────────────────────────────────────────────────────────────────────────────
Rectangle {
    id: botanicalGlow
    required property var shell    // voor shell.s() schaling
    required property var mocha    // kleurenpalet
    required property var surface  // barSurfaceRoot — heeft skinBool/skinNumber/continuousBarMode
    readonly property real barEnd: Math.max(0.12, Math.min(0.92, surface.visualContentHeight / Math.max(1, height)))

    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    anchors.topMargin: surface.visualContentY === 0 ? 0 : Math.max(0, surface.visualContentY - surface.particleOverflow)
    height: (surface.continuousBarMode ? surface.continuousRailHeight : surface.visualContentHeight) + surface.particleOverflow
    z: 0.1
    visible: surface.ambientEnabled("botanical-glow", "botanical") && surface.skinBool("showWarmGlow", false)
    opacity: surface.effectAlpha(surface.skinNumber("warmGlowAlpha", 0.04))

    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.0) }
        GradientStop { position: botanicalGlow.barEnd * 0.24; color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.85) }
        GradientStop { position: botanicalGlow.barEnd * 0.62; color: Qt.rgba(mocha.peach.r,  mocha.peach.g,  mocha.peach.b,  0.38) }
        GradientStop { position: botanicalGlow.barEnd; color: Qt.rgba(mocha.green.r,  mocha.green.g,  mocha.green.b,  0.24) }
        GradientStop { position: botanicalGlow.barEnd + (1.0 - botanicalGlow.barEnd) * 0.46; color: Qt.rgba(mocha.green.r,  mocha.green.g,  mocha.green.b,  0.09) }
        GradientStop { position: 1.0; color: Qt.rgba(mocha.green.r,  mocha.green.g,  mocha.green.b,  0.0) }
    }
}
