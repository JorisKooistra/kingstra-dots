// =============================================================================
// MediaPlayer.qml — Actieve media-info (playerctl)
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../" as Ks

Item {
    id: root
    implicitHeight: 26
    implicitWidth:  visible ? row.implicitWidth + 16 : 0
    visible:        title.length > 0

    property string title:  ""
    property string artist: ""
    property string status: ""  // "Playing" | "Paused" | "Stopped"

    readonly property string displayText: {
        const t = title.length  > 28 ? title.slice(0,26)  + "…" : title
        const a = artist.length > 20 ? artist.slice(0,18) + "…" : artist
        return a.length > 0 ? t + "  —  " + a : t
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color:  Ks.Colors.pillBackground
        visible: root.visible
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        visible: root.visible

        // Speel/pauzeer-icoon
        Text {
            text:  root.status === "Playing" ? "󰏤" : "󰐊"
            color: Ks.Colors.green
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    playerctlToggle.running = true
            }
        }

        // Titeltekst
        Text {
            text:  root.displayText
            color: Ks.Colors.subtext0
            font { family: "Fira Sans"; pixelSize: 12 }
        }

        // Volgend nummer
        Text {
            text:  "󰒭"
            color: Ks.Colors.subtext0
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    playerctlNext.running = true
            }
        }
    }

    // playerctl polling — elke 5 seconden
    Process {
        id: playerctlPoll
        command: ["playerctl", "metadata", "--format", "{{status}}\n{{title}}\n{{artist}}"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                const lines  = data.split("\n")
                root.status  = lines[0] ?? ""
                root.title   = lines[1] ?? ""
                root.artist  = lines[2] ?? ""
            }
        }
    }

    Timer {
        interval: 5000
        running:  true
        repeat:   true
        onTriggered: playerctlPoll.running = true
    }

    Process {
        id: playerctlToggle
        command: ["playerctl", "play-pause"]
        onExited: playerctlPoll.running = true
    }

    Process {
        id: playerctlNext
        command: ["playerctl", "next"]
        onExited: playerctlPoll.running = true
    }
}
