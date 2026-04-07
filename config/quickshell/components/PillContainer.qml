// =============================================================================
// PillContainer.qml — Herbruikbare afgeronde container (pill-stijl)
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "../"

Rectangle {
    id: root

    property alias content: contentLoader.sourceComponent
    property real  hPadding: 10
    property real  vPadding:  5
    property color bgColor:   Colors.pillBackground
    property real  radius:    height / 2   // Volledig afgerond

    implicitHeight: 26
    implicitWidth:  contentLoader.implicitWidth + hPadding * 2

    color:        bgColor
    radius:       root.radius

    Loader {
        id: contentLoader
        anchors {
            left:            parent.left
            right:           parent.right
            verticalCenter:  parent.verticalCenter
            leftMargin:      root.hPadding
            rightMargin:     root.hPadding
        }
    }
}
