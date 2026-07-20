import QtQuick

QtObject {
    readonly property real panelOpacityBoost: 0.00
    readonly property real hoverBoost: 0.12
    readonly property real borderBoost: 0.03
    readonly property real innerBoost: 0.10
    readonly property int cornerRadiusDelta: 8
    readonly property string moduleFillColorName: "surface0"
    readonly property string moduleHoverFillColorName: "surface1"
    readonly property string accentColorName: "teal"
    readonly property string accentHotColorName: "blue"
    readonly property string textHotColorName: "yellow"
    readonly property real chromeBorderAlphaMultiplier: 1.0
    readonly property bool showModuleTick: false
    readonly property bool showCyberGrid: false
    readonly property real gridAlpha: 0.0
    readonly property bool showWaveShimmer: true
    readonly property real waveShimmerAlpha: 0.13
    readonly property real waveCycleMs: 4200
}
