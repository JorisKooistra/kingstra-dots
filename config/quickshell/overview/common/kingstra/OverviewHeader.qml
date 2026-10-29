import QtQuick
import QtQuick.Layouts

// Kop van beide overzichten: kleine hoofdletter-titel en een uitlegregel in
// een afgeronde pil, zodat hij op elk thema en elke achtergrond leesbaar is.
Rectangle {
    id: header
    required property var look
    property string heading: ""
    property string hint: ""
    property string status: ""
    property bool statusIsError: false

    implicitWidth: column.implicitWidth + 36
    implicitHeight: column.implicitHeight + 18
    radius: Math.min(height / 2, look.panelRadius + 6)
    color: look.panelFill
    border.width: 1
    border.color: look.outline

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        width: Math.min(implicitWidth, header.width - 36)
        spacing: 3
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: header.heading.toUpperCase()
            color: header.look.text
            font.family: header.look.uiFont
            font.pixelSize: 12
            font.letterSpacing: 1.8
            font.bold: true
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: header.width - 36
            visible: text !== ""
            text: header.status || header.hint
            color: header.statusIsError && header.status ? header.look.red : header.look.subtext0
            font.family: header.look.uiFont
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
