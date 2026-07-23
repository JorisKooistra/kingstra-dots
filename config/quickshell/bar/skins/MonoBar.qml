import QtQuick

QtObject {
    readonly property real panelOpacityBoost: 0.10
    readonly property real hoverBoost: 0.02
    readonly property real borderBoost: 0.16
    readonly property real innerBoost: 0.00
    readonly property int cornerRadiusDelta: -48
    readonly property string moduleFillColorName: "crust"
    readonly property string moduleHoverFillColorName: "surface0"
    readonly property string accentColorName: "text"
    readonly property string accentHotColorName: "subtext0"
    readonly property string textHotColorName: "text"
    readonly property real chromeBorderAlphaMultiplier: 1.0
    readonly property bool showModuleTick: false
    readonly property bool continuousBar: true
}
