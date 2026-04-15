import QtQuick        // basisbouwstenen: Rectangle, Text, Item, Timer, ...
import QtQuick.Layouts // RowLayout, ColumnLayout (zoals flexbox)
import Quickshell      // execDetached en andere shell-functies
import "../../clock"   // DigitalClock, AnalogClock, SevenSegmentText

// ── Wat is dit bestand? ───────────────────────────────────────────────────────
// Dit is een herbruikbare QML-component: de middelste pill van de bar met
// klok en weer. Je "gebruikt" hem in BarContent.qml door zijn naam te typen:
//
//   CenterBox { shell: ...; surface: ...; mocha: ...; ctx: ... }
//
// Vergelijk het met een Python-klasse waarvan je een instantie maakt.
// ─────────────────────────────────────────────────────────────────────────────

// De root van dit bestand is een Rectangle — dat is de achtergrond van de pill.
// Alles wat je hier declareert hoort bij dat rechthoekje.
Rectangle {
    id: root   // 'root' is gewoon een naam zodat kindobjecten naar dit object
               // kunnen verwijzen met "root.xxx". Naam mag je zelf kiezen.

    // ── Parameters (verplicht mee te geven bij gebruik) ───────────────────────
    // In Python zou dit __init__(self, shell, surface, mocha, ctx) zijn.
    // 'var' = elk type (object, getal, string — maakt niet uit).
    required property var shell    // barWindow: data + helperfuncties
    required property var surface  // BarSurface: kleur/stijlinformatie
    required property var mocha    // kleurenpalet (Catppuccin-kleuren)
    required property var ctx      // BarContent: gedeelde theme-vlaggen

    // ── Eigen variabele ───────────────────────────────────────────────────────
    // Dit is een "binding": isHovered is ALTIJD gelijk aan containsMouse,
    // en updatet automatisch. Je hoeft geen event-handler te schrijven.
    // Vergelijk met een Python @property die zichzelf herberekent.
    property bool isHovered: centerMouse.containsMouse

    // ── Achtergrondkleur (reactief) ───────────────────────────────────────────
    // Dit is gewone ternary-logica, maar het verschil met PHP/Python is:
    // zodra isHovered verandert, past QML de kleur AUTOMATISCH aan.
    // Je hoeft niks te "aanroepen" — het systeem houdt dit bij.
    color: ctx.cyberCenterFeature
           ? (isHovered ? ctx.cyberCenterHoverColor : ctx.cyberCenterColor)
           : (isHovered ? surface.panelHoverColor   : surface.panelColor)

    // Afgeronde hoeken — normaal overal gelijk, maar bij botanical-thema
    // worden de hoeken die aan de schermrand zitten plat gemaakt (= 0).
    radius: ctx.cyberCenterFeature ? shell.s(6) : surface.panelRadius
    topLeftRadius:     ctx.panelTopLeftRadius
    topRightRadius:    ctx.panelTopRightRadius
    bottomLeftRadius:  ctx.panelBottomLeftRadius
    bottomRightRadius: ctx.panelBottomRightRadius

    border.width: 1
    border.color: ctx.cyberCenterFeature
                  ? (isHovered ? ctx.cyberCenterBorderHoverColor : ctx.cyberCenterBorderColor)
                  : (isHovered ? surface.panelBorderHoverColor   : surface.panelBorderColor)

    // Hoogte staat vast; breedte past zich aan aan de inhoud + wat padding.
    // shell.s(n) schaalt pixels mee met de schermresolutie.
    height: ctx.cyberCenterBodyHeight
    width: centerLayout.implicitWidth + (ctx.cyberCenterFeature ? shell.s(12) : shell.s(36))

    // ── Animaties ─────────────────────────────────────────────────────────────
    // "Behavior on X" betekent: als X verandert, animeer de overgang.
    // Zonder Behavior springt de waarde direct; met Behavior gaat het vloeiend.
    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
    Behavior on color { ColorAnimation  { duration: 250 } }

    // ── Opstartanimatie (slide in van boven) ──────────────────────────────────
    // showLayout begint op false. Na 150ms zet de Timer hem op true.
    // Doordat opacity en de y-positie aan showLayout gebonden zijn,
    // verandert de UI automatisch — inclusief animatie via Behavior.
    property bool showLayout: false
    opacity: showLayout ? 1 : 0
    transform: Translate {
        // y=0 is de eindpositie; y=-30 is de startpositie (boven de bar).
        y: root.showLayout ? 0 : shell.s(-30)
        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
    }

    // Timer: voert eenmalig code uit na 'interval' milliseconden.
    // 'running: shell.isStartupReady' start de timer pas als de bar klaar is.
    Timer {
        running: shell.isStartupReady
        interval: 150
        onTriggered: root.showLayout = true  // dit triggert de animatie hierboven
    }
    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    // Lichte vergrotingsanimatie bij hover (uitgeschakeld voor cyber-thema).
    scale: ctx.cyberCenterFeature ? 1.0 : (isHovered ? 1.03 : 1.0)
    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

    // ── Muisgebied ────────────────────────────────────────────────────────────
    // MouseArea vangt muisgebeurtenissen op. Zonder dit reageert een Rectangle
    // nergens op — QML-objecten hebben standaard geen klikgedrag.
    // 'hoverEnabled: true' zorgt dat containsMouse werkt (voor isHovered).
    MouseArea {
        id: centerMouse
        anchors.left: parent.left    // 'parent' = de Rectangle hierboven (root)
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height
        hoverEnabled: true
        onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])
    }

    // ── Inhoud: klok + weer naast elkaar ─────────────────────────────────────
    // RowLayout plaatst zijn kinderen horizontaal naast elkaar,
    // vergelijkbaar met display:flex; flex-direction:row in CSS.
    RowLayout {
        id: centerLayout
        anchors.centerIn: parent   // gecentreerd in de Rectangle
        spacing: ctx.cyberCenterFeature ? shell.s(6) : shell.s(24)

        // ── Klok ──────────────────────────────────────────────────────────────
        // Item is een onzichtbare container — puur voor groepering/sizing.
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: clockLoader.implicitWidth
            implicitHeight: clockLoader.implicitHeight

            // Loader rendert één van meerdere componenten op basis van een conditie.
            // Vergelijk met: if style == "analog": render AnalogClock
            Loader {
                id: clockLoader
                anchors.centerIn: parent
                sourceComponent: {
                    // Dit blok is JavaScript. Het geeft een Component-object terug.
                    let style = String(shell.clockStyle || "digital").toLowerCase();
                    if (style === "analog") return analogClockComponent;
                    if (style === "hybrid") return hybridClockComponent;
                    return digitalClockComponent;
                }
            }

            // Component is een "template" — het wordt pas gebouwd als een Loader
            // het aanvraagt. Vergelijk met een klasse die nog niet geïnstantieerd is.
            Component {
                id: digitalClockComponent
                DigitalClock { shell: root.shell; mocha: root.mocha; cyberScale: 1.0 }
            }
            Component {
                id: analogClockComponent
                AnalogClock { shell: root.shell; mocha: root.mocha; showSecondHand: false }
            }
            Component {
                id: hybridClockComponent
                RowLayout {
                    spacing: shell.s(8)
                    AnalogClock { shell: root.shell; mocha: root.mocha; showSecondHand: false }
                    Text {
                        text: shell.timeStr   // shell.timeStr update elke seconde in BarShell
                        Layout.alignment: Qt.AlignVCenter
                        font.family: shell.displayFontFamily
                        font.pixelSize: shell.s(14)
                        font.weight: shell.themeFontWeight
                        font.letterSpacing: shell.themeLetterSpacing
                        color: mocha.blue
                    }
                }
            }
        }

        // Cyber-stijl verticale scheidingslijn (momenteel uitgeschakeld)
        Item {
            visible: false
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: shell.s(10)
            Layout.preferredHeight: shell.s(48)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: parent.height
                color: ctx.cyberCenterDividerColor
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0; width: shell.s(5); height: shell.s(2)
                color: ctx.cyberCenterDividerColor
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: shell.s(5); height: shell.s(2)
                color: ctx.cyberCenterDividerColor
            }
        }

        // ── Weer ──────────────────────────────────────────────────────────────
        RowLayout {
            spacing: shell.s(7)
            Layout.alignment: Qt.AlignVCenter

            // Weericoon (Unicode-symbool uit Nerd Font)
            Text {
                text: shell.weatherIcon   // bijv. "⛅" — wordt opgehaald door BarShell
                Layout.alignment: Qt.AlignVCenter
                font.family: "Iosevka Nerd Font"
                font.pixelSize: shell.s(20)
                color: ctx.cyberChrome
                       ? ctx.cyberTextHotColor
                       : Qt.tint(shell.weatherHex, Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.4))
            }

            // Temperatuur — cyber-thema toont 7-segment display, rest gewone tekst
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: weatherTempLoader.implicitWidth
                implicitHeight: weatherTempLoader.implicitHeight

                Loader {
                    id: weatherTempLoader
                    anchors.centerIn: parent
                    sourceComponent: ctx.cyberCenterFeature ? cyberWeatherTempComponent : defaultWeatherTempComponent
                }

                Component {
                    id: cyberWeatherTempComponent
                    SevenSegmentText {
                        text: String(shell.weatherTemp || "--°C")
                        glyphWidth: shell.s(9)
                        glyphHeight: shell.s(14)
                        glyphSpacing: shell.s(1)
                        segmentOnColor: ctx.cyberWeatherTempOnColor
                        segmentOffColor: ctx.cyberWeatherTempOffColor
                    }
                }
                Component {
                    id: defaultWeatherTempComponent
                    Text {
                        text: shell.weatherTemp   // bijv. "18°C"
                        font.family: shell.monoFontFamily
                        font.pixelSize: shell.s(14)
                        font.weight: shell.themeFontWeight
                        font.letterSpacing: shell.themeLetterSpacing
                        color: ctx.cyberChrome ? ctx.cyberTextHotColor : mocha.peach
                    }
                }
            }
        }
    }
}
