import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: slider
    // Gedeelde schuifregelaar voor de shell-panelen (Snelle instellingen,
    // Geluid & media). Kleuren en hoekradius komen van het paneel zelf.
    required property var mocha
    property int itemRadius: 12
    property string icon: ""
    property string label: ""
    property int value: 0
    property bool dimmed: false
    property color accent: slider.mocha.primary
    property string detailTooltip: ""
    property string valueText: label + "  " + Math.max(0, value) + "%"
    // Zonder icoon (bijv. een voortgangsbalk) valt het knopje links weg.
    property bool showIcon: true
    signal iconClicked()
    signal moved(real percent)
    signal dragToggled(bool dragging)
    signal detailRequested()

    Layout.fillWidth: true
    spacing: 8

    Rectangle {
        visible: slider.showIcon
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: Math.min(slider.itemRadius, 16)
        color: iconMouse.containsMouse
            ? Qt.rgba(slider.accent.r, slider.accent.g, slider.accent.b, 0.22)
            : Qt.rgba(slider.mocha.text.r, slider.mocha.text.g, slider.mocha.text.b, 0.06)
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
        }
        Text {
            anchors.centerIn: parent
            text: slider.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 16
            color: slider.dimmed ? slider.mocha.subtext0 : slider.accent
        }
        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: slider.iconClicked()
        }
    }

    Item {
        id: track
        Layout.fillWidth: true
        Layout.preferredHeight: 32

        Rectangle {
            id: groove
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 10
            radius: height / 2
            color: Qt.rgba(slider.mocha.text.r, slider.mocha.text.g, slider.mocha.text.b, 0.10)

            Rectangle {
                width: Math.max(groove.height, groove.width * Math.max(0, Math.min(100, slider.value)) / 100)
                height: parent.height
                radius: parent.radius
                color: slider.dimmed
                    ? Qt.rgba(slider.accent.r, slider.accent.g, slider.accent.b, 0.35)
                    : slider.accent
                Behavior on width {
                    enabled: !trackMouse.pressed
                    NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                }
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.bottom: groove.top
            anchors.bottomMargin: 2
            text: slider.valueText
            font.family: ThemeConfig.monoFont
            font.pixelSize: 9
            font.weight: Font.Bold
            color: slider.mocha.subtext0
        }

        MouseArea {
            id: trackMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function apply(mx) {
                slider.moved(Math.max(0, Math.min(1, mx / Math.max(1, width))) * 100);
            }
            onPressed: (mouse) => { slider.dragToggled(true); apply(mouse.x); }
            onPositionChanged: (mouse) => { if (pressed) apply(mouse.x); }
            onReleased: slider.dragToggled(false)
            onCanceled: slider.dragToggled(false)
            onWheel: (wheel) => {
                slider.moved(slider.value + (wheel.angleDelta.y > 0 ? 5 : -5));
                wheel.accepted = true;
            }
        }
    }

    Rectangle {
        visible: slider.detailTooltip !== ""
        Layout.preferredWidth: 24
        Layout.preferredHeight: 28
        radius: Math.min(slider.itemRadius, 10)
        color: sliderDetailMouse.containsMouse
            ? Qt.rgba(slider.mocha.text.r, slider.mocha.text.g, slider.mocha.text.b, 0.10)
            : "transparent"
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
        }
        Text {
            anchors.centerIn: parent
            text: "󰅂"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 14
            color: sliderDetailMouse.containsMouse ? slider.mocha.text : slider.mocha.subtext0
        }
        MouseArea {
            id: sliderDetailMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: slider.detailRequested()
        }
    }
}
