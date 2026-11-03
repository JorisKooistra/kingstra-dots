import QtQuick
import QtQuick.Layouts
import "../"

// Kaart voor de eenvoudige instellingenpagina's: icoon, kop, één zin uitleg
// en daaronder de keuzes. Zelfde ronde vorm als de rest van de shell.
Rectangle {
    id: card
    required property var colors
    property string heading: ""
    property string hint: ""
    property string glyph: ""
    default property alias content: body.data

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + 32
    radius: Math.max(14, ThemeConfig.styleWidgetRadius)
    color: Qt.alpha(colors.shellRaisedFill, 0.55)
    border.width: 1
    border.color: colors.shellOutline
    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(200) } }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: card.heading !== ""
            Rectangle {
                visible: card.glyph !== ""
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: width / 2
                color: Qt.alpha(card.colors.primary, 0.16)
                Text {
                    anchors.centerIn: parent
                    text: card.glyph
                    color: card.colors.primary
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 16
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: card.heading
                    color: card.colors.text
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: card.hint !== ""
                    text: card.hint
                    color: card.colors.subtext0
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 12
        }
    }
}
