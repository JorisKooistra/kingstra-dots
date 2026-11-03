import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."

// Snelle instellingen vanuit de rail of de statustegel. Dit is precies
// dezelfde inhoud als de linkerkolom van het controlecentrum
// (ControlToggles): dezelfde knoppen, dezelfde volgorde en dezelfde
// bewerkmodus, waar je hem ook opent. Vroeger waren dit twee panelen met
// elk een eigen set tegels.
// De vorm (blob, hoeken, groei-animatie) komt volledig uit PanelHost.
Item {
    id: root

    // PanelHost luistert hiernaar: wisselen naar een detailpaneel gebeurt
    // in dezelfde host, dus met dezelfde blob-overgang als een railklik.
    signal panelSwitchRequested(string entryId)
    property string requestedNetworkMode: ""

    readonly property int pad: 16
    readonly property int preferredPanelWidth: 380
    readonly property int preferredPanelHeight: Math.ceil(toggles.implicitHeight + pad * 2)

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: root.pad
        clip: true
        contentWidth: width
        contentHeight: toggles.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ControlToggles {
            id: toggles
            width: flick.width
            screenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            onPanelSwitchRequested: (entryId) => {
                root.requestedNetworkMode = toggles.requestedNetworkMode;
                root.panelSwitchRequested(entryId);
            }
        }
    }
}
