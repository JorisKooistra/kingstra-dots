import QtQuick

Item {
    id: root
    required property var shell
    required property var mocha
    property bool showSecondHand: false

    property date now: new Date()
    readonly property real hourAngle: ((now.getHours() % 12) + now.getMinutes() / 60) * 30
    readonly property real minuteAngle: (now.getMinutes() + now.getSeconds() / 60) * 6
    readonly property real secondAngle: now.getSeconds() * 6

    implicitWidth: shell.s(30)
    implicitHeight: shell.s(30)

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Rectangle {
        id: dial
        anchors.centerIn: parent
        width: root.implicitWidth
        height: root.implicitHeight
        radius: width / 2
        color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.65)
        border.width: 1
        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.22)

        Item {
            id: hourPivot
            anchors.fill: parent
            rotation: root.hourAngle

            Rectangle {
                width: shell.s(2)
                height: shell.s(8)
                radius: width / 2
                color: mocha.text
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                anchors.bottomMargin: -shell.s(1)
            }
        }

        Item {
            id: minutePivot
            anchors.fill: parent
            rotation: root.minuteAngle

            Rectangle {
                width: shell.s(2)
                height: shell.s(11)
                radius: width / 2
                color: mocha.blue
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                anchors.bottomMargin: -shell.s(1)
            }
        }

        Item {
            anchors.fill: parent
            visible: root.showSecondHand
            rotation: root.secondAngle

            Rectangle {
                width: 1
                height: shell.s(12)
                color: mocha.red
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
            }
        }

        Rectangle {
            width: shell.s(4)
            height: shell.s(4)
            radius: width / 2
            color: mocha.text
            anchors.centerIn: parent
        }
    }
}
