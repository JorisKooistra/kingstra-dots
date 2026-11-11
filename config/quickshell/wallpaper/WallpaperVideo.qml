import QtQuick
import QtMultimedia

// Apart bestand: zonder qt6-multimedia faalt alleen deze Loader en blijft de
// picker gewoon werken (met het stilstaande voorbeeld).
Item {
    id: root
    property url source
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    readonly property bool ready: player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.LoadedMedia || playing
    readonly property bool failed: player.error !== MediaPlayer.NoError

    MediaPlayer {
        id: player
        source: root.source
        loops: MediaPlayer.Infinite
        videoOutput: output
        onSourceChanged: if (source.toString()) play()
    }
    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }
    function toggle() {
        if (playing) player.pause();
        else player.play();
    }
    Component.onCompleted: if (source.toString()) player.play()
}
