pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// TmpWatch — één inotifywait voor de kleine statusbestanden in /tmp die
// scripts schrijven (sneltoetsen, feedback, eiland-OSD, spiekbriefje).
// FileView mist op Quickshell 0.3 af en toe een schrijfactie; daarom pollden
// die bestanden elk 75–125 ms, per scherm. Dat kostte de bovenbalk in rust
// zo'n 8% CPU. Met deze ene watcher lezen ze alleen nog als er echt iets
// verandert; de poll valt terug naar een rustig vangnet. Zonder inotifywait
// (inotify-tools) blijft alles werken zoals vroeger.
Item {
    id: root

    // true zolang inotifywait draait en de watch staat.
    property bool available: false
    signal changed(string path)

    readonly property var watched: [
        "/tmp/qs_widget_state",
        "/tmp/kingstra-feedback.json",
        "/tmp/kingstra-island.json",
        "/tmp/kingstra-superhold"
    ]

    // Interval voor een poll: snel zonder watcher, rustig met.
    function pollInterval(fastMs) {
        return root.available ? 2000 : fastMs;
    }

    Process {
        id: watcher
        running: true
        command: ["sh", "-c",
            "command -v inotifywait >/dev/null 2>&1 || exit 3; " +
            "exec inotifywait -m -q -e close_write,moved_to,create --format '%w%f' " +
            "--include '^/tmp/(qs_widget_state|kingstra-(feedback\\.json|island\\.json|superhold))$' /tmp"]
        stdout: SplitParser {
            onRead: line => {
                root.available = true;
                root.changed(String(line).trim());
            }
        }
        onStarted: readyTimer.restart()
        onExited: {
            root.available = false;
            // Opnieuw proberen, behalve als inotifywait ontbreekt.
            if (exitCode !== 3) restartTimer.restart();
        }
    }
    // inotifywait meldt niets bij het starten; na een halve seconde zonder
    // afsluiten staat de watch.
    Timer { id: readyTimer; interval: 500; onTriggered: if (watcher.running) root.available = true }
    Timer { id: restartTimer; interval: 5000; onTriggered: watcher.running = true }
}
