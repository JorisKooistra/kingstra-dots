import QtQuick

QtObject {
    readonly property real panelOpacityBoost: 0.12
    readonly property real hoverBoost: 0.24
    readonly property real borderBoost: 0.26
    readonly property real innerBoost: 0.04
    readonly property int cornerRadiusDelta: -4
    readonly property string moduleFillColorName: "crust"
    readonly property string moduleHoverFillColorName: "surface0"
    readonly property string accentColorName: "mauve"
    readonly property string accentHotColorName: "teal"
    readonly property string textHotColorName: "pink"
    readonly property real chromeBorderAlphaMultiplier: 1.18
    readonly property bool showModuleTick: true
    readonly property bool continuousBar: true
    readonly property bool continuousBarTopOnly: true
    readonly property bool showNeonGrid: true
    readonly property real gridAlpha: 1.08
    readonly property real neonNodeAlpha: 0.88
    readonly property real neonLaneAlpha: 0.72
}
