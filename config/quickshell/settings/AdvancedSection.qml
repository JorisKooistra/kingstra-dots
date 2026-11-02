import QtQuick
import QtQuick.Layouts
import "../"

// Uitklapbaar blok voor technische keuzes. Eenvoudige instellingen staan
// erboven; wat hierin zit blijft altijd bestaan (geen Loader), zodat
// opslaan-knoppen elders hun velden blijven vinden en niets verloren gaat.
// Ingeklapt is het blok 0 hoog en niet bedienbaar; openen schuift het
// zacht open met een draaiende pijl.
ColumnLayout {
    id: section

    property string title: "Geavanceerd"
    property string hint: ""
    property string icon: "󰒓"
    property bool expanded: false
    // Schaal van de pagina: SettingsPopup geeft root.s(100) / 100 mee.
    property real unit: 1.0
    default property alias content: body.data

    function toggle() { expanded = !expanded; }

    Layout.fillWidth: true
    spacing: 0

    MatugenColors { id: sectionColors }

    Rectangle {
        id: header
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(46 * section.unit)
        radius: Math.round(Math.max(10, ThemeConfig.styleWidgetRadius - 2) * section.unit)
        color: headerMouse.containsMouse ? sectionColors.shellHoverFill
            : section.expanded ? Qt.alpha(sectionColors.primary, 0.10) : Qt.alpha(sectionColors.shellRaisedFill, 0.55)
        border.width: 1
        border.color: section.expanded ? Qt.alpha(sectionColors.primary, 0.55) : sectionColors.shellOutline
        scale: headerMouse.pressed ? 0.985 : 1.0
        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(160) } }
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(160) } }
        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * section.unit)
            anchors.rightMargin: Math.round(14 * section.unit)
            spacing: Math.round(10 * section.unit)

            Text {
                text: section.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: Math.round(16 * section.unit)
                color: section.expanded ? sectionColors.primary : sectionColors.subtext0
                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(160) } }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: section.title
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: Math.round(12 * section.unit)
                    font.bold: true
                    color: sectionColors.text
                }
                Text {
                    visible: section.hint !== ""
                    text: section.hint
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: Math.round(10 * section.unit)
                    color: sectionColors.subtext0
                }
            }
            Text {
                text: section.expanded ? "Inklappen" : "Openklappen"
                font.family: ThemeConfig.uiFont
                font.pixelSize: Math.round(10 * section.unit)
                color: sectionColors.subtext0
            }
            Text {
                text: "󰅀"
                font.family: ThemeConfig.iconFont
                font.pixelSize: Math.round(16 * section.unit)
                color: section.expanded ? sectionColors.primary : sectionColors.subtext0
                rotation: section.expanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: ThemeConfig.duration(260); easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(160) } }
            }
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: section.toggle()
        }
    }

    // Het venster: hoogte en doorzichtigheid schuiven mee; clip houdt de
    // inhoud binnen de ronde vorm tijdens het openen.
    Item {
        id: drawer
        Layout.fillWidth: true
        Layout.preferredHeight: section.expanded ? body.implicitHeight + Math.round(14 * section.unit) : 0
        clip: true
        enabled: section.expanded
        opacity: section.expanded ? 1.0 : 0.0
        Behavior on Layout.preferredHeight { NumberAnimation { duration: ThemeConfig.duration(280); easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(220) } }

        ColumnLayout {
            id: body
            anchors.top: parent.top
            anchors.topMargin: Math.round(14 * section.unit)
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Math.round(14 * section.unit)
        }
    }
}
