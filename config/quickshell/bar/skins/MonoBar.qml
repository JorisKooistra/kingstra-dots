import QtQuick

QtObject {
    readonly property real panelOpacityBoost: 0.08
    readonly property real hoverBoost: 0.03
    readonly property real borderBoost: 0.10
    readonly property real innerBoost: 0.00
    readonly property int cornerRadiusDelta: -6
    readonly property string moduleFillColorName: "surface0"
    readonly property string moduleHoverFillColorName: "surface1"
    readonly property string accentColorName: "text"
    readonly property string accentHotColorName: "subtext0"
    readonly property string textHotColorName: "text"
    readonly property real chromeBorderAlphaMultiplier: 1.0
    readonly property bool showModuleTick: false
    readonly property bool continuousBar: true
}
