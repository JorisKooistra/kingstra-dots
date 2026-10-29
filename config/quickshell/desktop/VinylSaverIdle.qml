import QtQuick
import Quickshell
import Quickshell.Wayland

// Draaitafel als screensaver: na `timeout` seconden zonder invoer, terwijl er
// muziek speelt, opent DesktopWidgets de schermvullende speler. Bij de eerste
// beweging sluit hij weer, maar alleen als hij vanzelf open ging.
// Apart bestand via een LazyLoader: kent Quickshell IdleMonitor niet, dan
// valt alleen dit weg en blijven klok en mediakaart werken.
Scope {
    id: saver

    property var host: null
    property real timeout: 120
    // Zelf geopend; dan mag het ook vanzelf dicht.
    property bool autoOpened: false

    IdleMonitor {
        enabled: saver.host !== null && saver.timeout > 0
        // Video in een browser of een presentatie houdt het scherm wakker.
        respectInhibitors: true
        timeout: saver.timeout
        onIsIdleChanged: {
            let h = saver.host;
            if (!h) return;
            if (isIdle) {
                if (h.playing && !h.stageOpen) {
                    h.openStage();
                    saver.autoOpened = true;
                }
            } else if (saver.autoOpened) {
                saver.autoOpened = false;
                h.stageOpen = false;
            }
        }
    }

    // Handmatig gesloten of geopend: niet meer als screensaver behandelen.
    Connections {
        target: saver.host
        function onStageOpenChanged() {
            if (saver.host && !saver.host.stageOpen) saver.autoOpened = false;
        }
    }
}
