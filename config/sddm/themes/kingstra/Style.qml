// Themastijl voor het inlogscherm — terugvalwaarden (Organic).
// kingstra-sddm-sync overschrijft dit bestand met het actieve thema uit
// ~/.config/quickshell/theme.json, zodat lettertype, tempo en sfeer gelijk
// lopen met de shell en het vergrendelscherm.
pragma Singleton
import QtQuick

QtObject {
    readonly property string theme: "organic"
    readonly property string name: "Organic"
    readonly property string family: "organic"
    readonly property bool light: false
    readonly property string uiFont: "Fira Sans"
    readonly property string monoFont: "Fira Code"
    readonly property string displayFont: "Fira Sans"
    // Vermenigvuldiger voor animatieduur (ThemeConfig.motionDurationScale).
    readonly property real motionScale: 1.17
    readonly property real glow: 0.12
    readonly property string texture: "grain"
    readonly property real textureOpacity: 0.06
}
