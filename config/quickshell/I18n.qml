pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0
    height: 0
    property string language: "nl"
    property var defaultStrings: ({})
    property var activeStrings: ({})

    function t(key, fallback) {
        if (activeStrings[key] !== undefined) return String(activeStrings[key]);
        if (defaultStrings[key] !== undefined) return String(defaultStrings[key]);
        return fallback !== undefined ? String(fallback) : String(key);
    }

    function loadSessionLanguage() {
        sessionReader.running = true;
    }

    function loadTranslations() {
        defaultReader.running = true;
        activeReader.running = true;
    }

    onLanguageChanged: loadTranslations()

    Component.onCompleted: {
        loadTranslations();
        loadSessionLanguage();
    }

    Process {
        id: sessionReader
        command: ["bash", "-c", "jq -r '.language // \"nl\"' \"$HOME/.config/kingstra/state/session.json\" 2>/dev/null || echo nl"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lang = this.text.trim();
                if (lang !== "") root.language = lang;
            }
        }
    }

    Process {
        id: defaultReader
        command: ["bash", "-c",
            "for p in \"$HOME/.config/kingstra-dots/config/kingstra/i18n/nl.json\" \"$HOME/kingstra-dots/config/kingstra/i18n/nl.json\"; do " +
            "[ -f \"$p\" ] && { cat \"$p\"; exit 0; }; done; echo '{}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (raw === "") raw = "{}";
                try {
                    root.defaultStrings = JSON.parse(raw);
                } catch (e) {
                    root.defaultStrings = ({});
                }
            }
        }
    }

    Process {
        id: activeReader
        command: ["bash", "-c",
            "lang=\"" + root.language + "\"; " +
            "for p in \"$HOME/.config/kingstra-dots/config/kingstra/i18n/${lang}.json\" \"$HOME/kingstra-dots/config/kingstra/i18n/${lang}.json\"; do " +
            "[ -f \"$p\" ] && { cat \"$p\"; exit 0; }; done; echo '{}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (raw === "") raw = "{}";
                try {
                    root.activeStrings = JSON.parse(raw);
                } catch (e) {
                    root.activeStrings = ({});
                }
            }
        }
    }
}
