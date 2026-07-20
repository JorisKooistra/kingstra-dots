import QtQuick

QtObject {
    readonly property real panelOpacityBoost: 0.08
    readonly property real hoverBoost: 0.16
    readonly property real borderBoost: 0.12
    readonly property real innerBoost: 0.02
    readonly property int cornerRadiusDelta: -2
    readonly property string moduleFillColorName: "crust"
    readonly property string moduleHoverFillColorName: "surface0"
    readonly property string accentColorName: "blue"
    readonly property string accentHotColorName: "teal"
    readonly property string textHotColorName: "yellow"
    readonly property real chromeBorderAlphaMultiplier: 1.0
    readonly property bool showModuleTick: true
    readonly property bool continuousBar: true
    readonly property bool continuousBarTopOnly: true
    readonly property bool showCyberGrid: true
    readonly property real gridAlpha: 0.82
}
