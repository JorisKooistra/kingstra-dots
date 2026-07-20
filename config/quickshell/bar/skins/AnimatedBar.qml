import QtQuick

QtObject {
    readonly property real panelOpacityBoost: 0.04
    readonly property real hoverBoost: 0.12
    readonly property real borderBoost: 0.05
    readonly property real innerBoost: 0.09
    readonly property int cornerRadiusDelta: 8
    readonly property string moduleFillColorName: "surface0"
    readonly property string moduleHoverFillColorName: "surface1"
    readonly property string accentColorName: "pink"
    readonly property string accentHotColorName: "yellow"
    readonly property string textHotColorName: "yellow"
    readonly property real chromeBorderAlphaMultiplier: 1.0
    readonly property bool showModuleTick: false
    readonly property bool showCyberGrid: false
    readonly property real gridAlpha: 0.0
    readonly property bool showRainbowShift: true
    readonly property real rainbowCycleMs: 3800
    readonly property real rainbowAlpha: 0.22
}
