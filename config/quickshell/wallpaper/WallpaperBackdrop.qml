import QtQuick

Item {
    id: backdrop
    property url source: ""
    property color veil: "#11111b"
    property bool shown: true
    property bool first: true
    readonly property bool ready: front.status === Image.Ready || back.status === Image.Ready
    function load() {
        if (!source) return;
        let image = first ? back : front;
        if (String(image.source) === String(source) && image.status === Image.Ready) first = image === front;
        else image.source = source;
    }
    onSourceChanged: settle.restart()
    Timer { id: settle; interval: 140; onTriggered: backdrop.load() }
    // Workers blur one tiny cached thumbnail. No full-resolution decoder or
    // continuously running blur effect is added to the scrolling scene.
    Image {
        id: front
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: backdrop.first && backdrop.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        onStatusChanged: if (status === Image.Ready && String(source) === String(backdrop.source)) backdrop.first = true
    }
    Image {
        id: back
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: !backdrop.first && backdrop.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        onStatusChanged: if (status === Image.Ready && String(source) === String(backdrop.source)) backdrop.first = false
    }
    opacity: shown && !!source ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 220 } }
    Rectangle {
        id: veilLayer
        anchors.fill: parent
        readonly property bool light: (0.2126 * backdrop.veil.r + 0.7152 * backdrop.veil.g + 0.0722 * backdrop.veil.b) > 0.5
        function shade(alpha) { return Qt.rgba(backdrop.veil.r, backdrop.veil.g, backdrop.veil.b, alpha); }
        gradient: Gradient {
            GradientStop { position: 0; color: veilLayer.shade(veilLayer.light ? 0.96 : 0.87) }
            GradientStop { position: 0.3; color: veilLayer.shade(veilLayer.light ? 0.88 : 0.56) }
            GradientStop { position: 0.6; color: veilLayer.shade(veilLayer.light ? 0.87 : 0.46) }
            GradientStop { position: 0.85; color: veilLayer.shade(veilLayer.light ? 0.94 : 0.84) }
            GradientStop { position: 1; color: veilLayer.shade(veilLayer.light ? 0.96 : 0.94) }
        }
    }
}
