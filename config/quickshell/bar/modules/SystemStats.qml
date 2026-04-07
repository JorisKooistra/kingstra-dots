// =============================================================================
// SystemStats.qml — CPU en RAM gebruik
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../" as Ks

Item {
    id: root
    implicitHeight: 26
    implicitWidth:  row.implicitWidth + 16

    signal toggleStatsMenu

    // CPU-staat bijhouden voor percentage-berekening
    property var  _prevCpu:  null
    property real cpuPercent: 0
    property real ramPercent: 0
    property int  ramUsedMb:  0

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color:  hoverArea.containsMouse
                ? Qt.rgba(Ks.Colors.primary.r, Ks.Colors.primary.g, Ks.Colors.primary.b, 0.15)
                : Ks.Colors.pillBackground
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id:           hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked:    root.toggleStatsMenu()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10

        // CPU
        RowLayout {
            spacing: 4
            Text {
                text:  ""
                color: Ks.Colors.blue
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
            }
            Text {
                text:  root.cpuPercent.toFixed(0) + "%"
                color: root.cpuPercent > 80 ? Ks.Colors.red
                     : root.cpuPercent > 50 ? Ks.Colors.yellow
                     : Ks.Colors.subtext0
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        // Scheidingsteken
        Rectangle {
            width: 1; height: 14
            color: Qt.rgba(Ks.Colors.outline.r, Ks.Colors.outline.g, Ks.Colors.outline.b, 0.4)
        }

        // RAM
        RowLayout {
            spacing: 4
            Text {
                text:  "󰍛"
                color: Ks.Colors.mauve
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
            }
            Text {
                text:  root.ramUsedMb + "MB"
                color: root.ramPercent > 80 ? Ks.Colors.red
                     : root.ramPercent > 60 ? Ks.Colors.yellow
                     : Ks.Colors.subtext0
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }

    // /proc/stat — CPU
    FileView {
        id: cpuFile
        path: "/proc/stat"
        onTextChanged: _parseCpu(text)
    }

    // /proc/meminfo — RAM
    FileView {
        id: memFile
        path: "/proc/meminfo"
        onTextChanged: _parseMem(text)
    }

    // Prikkel beide bestanden elke 3 seconden
    Timer {
        interval: 3000
        running:  true
        repeat:   true
        onTriggered: {
            cpuFile.reload()
            memFile.reload()
        }
    }

    function _parseCpu(text) {
        const line = text.split("\n")[0]
        const parts = line.split(/\s+/).slice(1).map(Number)
        const idle  = parts[3]
        const total = parts.reduce((a, b) => a + b, 0)

        if (_prevCpu) {
            const dIdle  = idle  - _prevCpu.idle
            const dTotal = total - _prevCpu.total
            cpuPercent = dTotal > 0 ? Math.max(0, Math.min(100, (1 - dIdle / dTotal) * 100)) : 0
        }
        _prevCpu = { idle, total }
    }

    function _parseMem(text) {
        const lines  = text.split("\n")
        const vals   = {}
        for (const line of lines) {
            const m = line.match(/^(\w+):\s+(\d+)/)
            if (m) vals[m[1]] = parseInt(m[2])
        }
        const totalKb   = vals["MemTotal"]   ?? 1
        const availKb   = vals["MemAvailable"] ?? 0
        const usedKb    = totalKb - availKb
        ramUsedMb   = Math.round(usedKb / 1024)
        ramPercent  = (usedKb / totalKb) * 100
    }

    Component.onCompleted: {
        cpuFile.reload()
        memFile.reload()
    }
}
