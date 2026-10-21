pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root
    property bool overviewOpen: false
    // Monitor waarop het overzicht opent; vastgelegd bij openen zodat het niet
    // meeverhuist als de focus tijdens het overzicht naar een ander scherm gaat.
    property string overviewScreenName: ""
    property bool superReleaseMightTrigger: true
}
