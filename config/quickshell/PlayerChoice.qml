pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Welke speler er op de mediakaart en schermvullend staat, per thema:
// platenspeler, cassettespeler, discman, alleen de hoes, of "theme" (wat
// bij het thema hoort). Te kiezen in Super+A, in Instellingen › Bediening en
// met de knoppen in de schermvullende speler. Opgeslagen als regels
// "thema=speler", zodat de keuze een herstart overleeft.
Item {
    id: root

    readonly property var known: ["theme", "vinyl", "cassette", "discman", "cover"]
    property var byTheme: ({})
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/kingstra/player-style"

    // Keuze voor het huidige thema; leeg als er niets gekozen is.
    readonly property string current: byTheme[ThemeConfig.theme] || ""

    // Wat er echt getoond wordt: de keuze voor dit thema, anders de oude
    // keuze per scherm, anders wat bij het thema hoort.
    function effective(screenStyle) {
        if (current !== "") return current;
        return screenStyle || "theme";
    }

    function set(style) {
        if (known.indexOf(style) === -1) return;
        let next = Object.assign({}, byTheme);
        next[ThemeConfig.theme] = style;
        byTheme = next;
        let lines = [];
        for (let t in next) lines.push(t + "=" + next[t]);
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"",
            "sh", stateFile, lines.join("\n")]);
    }

    function parse(text) {
        let out = {};
        let rows = String(text || "").split("\n");
        for (let i = 0; i < rows.length; i++) {
            let parts = rows[i].trim().split("=");
            if (parts.length !== 2) continue;
            let theme = parts[0].trim(), style = parts[1].trim();
            if (theme !== "" && known.indexOf(style) !== -1) out[theme] = style;
        }
        byTheme = out;
    }

    FileView {
        path: root.stateFile
        preload: true
        watchChanges: true
        onLoaded: root.parse(text())
        onFileChanged: reload()
    }
}
