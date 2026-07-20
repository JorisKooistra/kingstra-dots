import QtQuick

QtObject {
    readonly property real panelOpacityBoost: 0.06
    readonly property real hoverBoost: 0.12
    readonly property real borderBoost: 0.08
    readonly property real innerBoost: 0.02
    readonly property int cornerRadiusDelta: -2
    readonly property string moduleFillColorName: "crust"
    readonly property string moduleHoverFillColorName: "surface0"
    readonly property string accentColorName: "blue"
    readonly property string accentHotColorName: "accent2"
    readonly property string textHotColorName: "yellow"
    readonly property real chromeBorderAlphaMultiplier: 0.90
    readonly property bool showModuleTick: true
    readonly property bool continuousBar: true
    readonly property bool continuousBarTopOnly: true
}
