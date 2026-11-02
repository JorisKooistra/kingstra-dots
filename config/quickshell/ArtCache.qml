pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Albumhoezen nooit zelf via https laden. Qt 6.12 crasht (SIGSEGV/SIGABRT in
// OpenSSL) als de afbeeldingenthread voor een https-hoes de certificaten
// inleest; dat haalde de hele bar onderuit. curl downloadt de hoes in een
// eigen proces naar ~/.cache/kingstra/covers en de spelers krijgen een
// file://-pad. Bijkomend voordeel: één download voor alle schermen.
//
// Gebruik: source: ArtCache.local(player.trackArtUrl)
// Geeft "" zolang de hoes nog binnenkomt; bindingen werken zichzelf bij.
Item {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/kingstra/covers"
    // Verhoogd bij elke klaargezette hoes, zodat bindingen opnieuw rekenen.
    property int revision: 0
    property var ready: ({})
    property var failed: ({})
    property var queue: []
    property string current: ""

    function remote(url) {
        return url.indexOf("https://") === 0 || url.indexOf("http://") === 0;
    }

    function pathFor(url) {
        return dir + "/" + Qt.md5(url);
    }

    function local(value) {
        let url = String(value || "");
        let rev = root.revision; // afhankelijkheid voor de binding
        if (url === "" || !remote(url)) return url;
        let key = Qt.md5(url);
        if (ready[key]) return "file://" + dir + "/" + key;
        if (!(failed[key] && Date.now() - failed[key] < 60000) && queue.indexOf(url) === -1 && current !== url) {
            queue.push(url);
            Qt.callLater(root.next);
        }
        return "";
    }

    function next() {
        if (fetcher.running || queue.length === 0) return;
        current = queue.shift();
        fetcher.outPath = pathFor(current);
        fetcher.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\" || exit 1; " +
            "[ -s \"$2\" ] && { touch \"$2\"; exit 0; }; " +
            "tmp=\"$2.part.$$\"; " +
            "curl -fsSL --max-time 15 --max-filesize 10485760 -o \"$tmp\" -- \"$1\" " +
            "&& [ -s \"$tmp\" ] && mv -f \"$tmp\" \"$2\" && exit 0; " +
            "rm -f \"$tmp\"; exit 1",
            "sh", current, fetcher.outPath];
        fetcher.running = true;
    }

    Process {
        id: fetcher
        property string outPath: ""
        onExited: code => {
            let key = Qt.md5(root.current);
            if (code === 0) {
                let r = root.ready; r[key] = true; root.ready = r;
                root.revision += 1;
            } else {
                let f = root.failed; f[key] = Date.now(); root.failed = f;
            }
            root.current = "";
            Qt.callLater(root.next);
        }
    }

    // Oude hoezen opruimen: alles wat 30 dagen niet gebruikt is.
    Component.onCompleted: Quickshell.execDetached(["sh", "-c",
        "find \"$1\" -maxdepth 1 -type f -mtime +30 -delete 2>/dev/null; " +
        "find \"$1\" -maxdepth 1 -name '*.part.*' -mmin +10 -delete 2>/dev/null; true",
        "sh", root.dir])
}
