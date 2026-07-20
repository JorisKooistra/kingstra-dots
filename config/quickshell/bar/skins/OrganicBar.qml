import QtQuick

QtObject {
    readonly property real panelOpacityBoost: 0.02
    readonly property real hoverBoost: 0.08
    readonly property real borderBoost: -0.08
    readonly property real innerBoost: 0.05
    readonly property int cornerRadiusDelta: 4
    readonly property string moduleFillColorName: "surface0"
    readonly property string moduleHoverFillColorName: "surface1"
    readonly property string accentColorName: "green"
    readonly property string accentHotColorName: "accent2"
    readonly property string textHotColorName: "peach"
    readonly property real chromeBorderAlphaMultiplier: 0.35
    readonly property bool showModuleTick: false
    readonly property bool showWarmGlow: true
    readonly property real warmGlowAlpha: 0.05
}
