import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import ".."

FocusScope {
    id: root

    MatugenColors { id: mocha }

    readonly property int pad: 16
    readonly property int panelRadius: Math.max(18, ThemeConfig.styleWidgetRadius + 6)
    readonly property int itemRadius: Math.max(12, Math.round(panelRadius * 0.56))
    readonly property color cardColor: mocha.shellRaisedFill
    readonly property color cardHoverColor: mocha.shellHoverFill
    readonly property color subtleBorder: mocha.shellOutline
    // Een leeg archief is een statuskaart, geen 620px-lange lade. Zodra er
    // meldingen zijn, groeit de lijst per kaart en blijft hij daarna scrollen.
    readonly property int preferredPanelHeight: NotificationService.count === 0
        ? 210
        : Math.min(620, 100 + groupColumn.implicitHeight)

    // Herberekend bij elke nieuwe of verdwenen melding.
    readonly property var groupList: {
        NotificationService.count;
        NotificationService.arrivedAt;
        return NotificationService.groups();
    }
    property var collapsedApps: ({})

    function toggleCollapsed(app) {
        let next = Object.assign({}, collapsedApps);
        next[app] = !next[app];
        collapsedApps = next;
    }

    function closePanel() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    function cleanText(value) {
        return String(value || "")
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<\/p>/gi, "\n")
            .replace(/<[^>]*>/g, "")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .trim();
    }

    function appInitial(notification) {
        let name = String(notification && notification.appName ? notification.appName : "?").trim();
        return name.length > 0 ? name.charAt(0).toUpperCase() : "?";
    }

    function urgencyColor(notification) {
        if (notification && notification.urgency === NotificationUrgency.Critical) return mocha.red;
        if (notification && notification.urgency === NotificationUrgency.Low) return mocha.subtext0;
        return mocha.yellow;
    }

    Keys.onEscapePressed: event => {
        closePanel();
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: root.itemRadius
                color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.16)

                Text {
                    anchors.centerIn: parent
                    text: NotificationService.dnd ? "󰂛" : "󰍜"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 19
                    color: mocha.yellow
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: "Meldingen"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 17
                    font.weight: Font.Black
                    color: mocha.text
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: (NotificationService.dnd ? "Niet storen · " : "")
                        + (NotificationService.count === 1
                            ? "1 melding"
                            : NotificationService.count + " meldingen")
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                    elide: Text.ElideRight
                }
            }

            HeaderButton {
                icon: NotificationService.dnd ? "󰂚" : "󰂛"
                tooltip: NotificationService.dnd ? "Niet storen uit" : "Niet storen aan"
                accent: mocha.mauve
                onTriggered: NotificationService.toggleDnd()
            }

            HeaderButton {
                icon: "󰆴"
                tooltip: "Alles wissen"
                accent: mocha.red
                enabled: NotificationService.count > 0
                onTriggered: NotificationService.clearAll()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 24, 320)
                spacing: 8
                visible: NotificationService.count === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: NotificationService.dnd ? "󰂛" : "󰂚"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 36
                    color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.28)
                }

                Text {
                    Layout.fillWidth: true
                    text: NotificationService.dnd ? "Ruststand staat aan" : "Geen meldingen"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    color: mocha.text
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    text: NotificationService.dnd
                        ? "Meldingen komen stil binnen. Alleen kritieke krijgen nog een pop-up."
                        : "Nieuwe meldingen verschijnen hier."
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    color: mocha.subtext0
                    wrapMode: Text.WordWrap
                }
            }

            // Per app gegroepeerd, nieuwste groep bovenaan. Een groep met
            // meerdere meldingen klapt in tot de nieuwste.
            Flickable {
                id: notificationList
                anchors.fill: parent
                visible: NotificationService.count > 0
                clip: true
                contentWidth: width
                contentHeight: groupColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: groupColumn
                    width: notificationList.width
                    spacing: 12

                    Repeater {
                        model: root.groupList

                        delegate: ColumnLayout {
                            id: group
                            required property var modelData
                            readonly property bool collapsed: !!root.collapsedApps[modelData.app]
                            readonly property var shownItems: collapsed ? modelData.items.slice(0, 1) : modelData.items
                            readonly property string groupIcon: NotificationService.iconSource(modelData.items[0])

                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 2
                                spacing: 7

                                Item {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    Image {
                                        id: groupIconImage
                                        anchors.fill: parent
                                        source: group.groupIcon
                                        sourceSize.width: 32
                                        sourceSize.height: 32
                                        visible: status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !groupIconImage.visible
                                        text: "󰍡"
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: 13
                                        color: mocha.subtext0
                                    }
                                }
                                Text {
                                    text: group.modelData.app
                                    font.family: ThemeConfig.displayFont
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: mocha.subtext1
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 220
                                }
                                Rectangle {
                                    visible: group.modelData.items.length > 1
                                    Layout.preferredHeight: 16
                                    Layout.preferredWidth: Math.max(16, countText.implicitWidth + 9)
                                    radius: 8
                                    color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: group.modelData.items.length
                                        font.family: ThemeConfig.monoFont
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: mocha.subtext0
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                IconButton {
                                    visible: group.modelData.items.length > 1
                                    icon: group.collapsed ? "󰅀" : "󰅃"
                                    accent: mocha.subtext0
                                    onTriggered: root.toggleCollapsed(group.modelData.app)
                                }
                                IconButton {
                                    icon: "󰆴"
                                    accent: mocha.subtext0
                                    onTriggered: NotificationService.dismissApp(group.modelData.app)
                                }
                            }

                            Repeater {
                                model: group.shownItems
                                delegate: NotificationCard {
                                    required property var modelData
                                    notification: modelData
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                visible: group.collapsed && group.modelData.items.length > 1
                                Layout.leftMargin: 4
                                text: "+ " + (group.modelData.items.length - 1) + " oudere"
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 10
                                color: mocha.subtext0
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleCollapsed(group.modelData.app)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Eén melding. Wegklikken (kruisje of rechtermuisknop) schuift de kaart
    // eerst opzij en sluit hem daarna pas.
    component NotificationCard: Rectangle {
        id: card
        property var notification: null
        property bool leaving: false
        readonly property color accent: root.urgencyColor(notification)
        readonly property string iconSource: NotificationService.iconSource(notification)
        readonly property var visibleActions: {
            let out = [];
            let actions = notification ? (notification.actions || []) : [];
            for (let i = 0; i < actions.length; i++) {
                if (String(actions[i].identifier || "") !== "default") out.push(actions[i]);
            }
            return out;
        }
        readonly property bool hasDefault: {
            let actions = notification ? (notification.actions || []) : [];
            for (let i = 0; i < actions.length; i++) {
                if (String(actions[i].identifier || "") === "default") return true;
            }
            return false;
        }

        function leave() {
            if (leaving) return;
            leaving = true;
            leaveAnim.start();
        }

        implicitHeight: contentRow.implicitHeight + 18
        radius: root.itemRadius
        color: cardHover.hovered ? root.cardHoverColor : root.cardColor
        border.width: 1
        border.color: root.subtleBorder
        transform: Translate { id: leaveShift; x: 0 }

        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
        }

        SequentialAnimation {
            id: leaveAnim
            ParallelAnimation {
                NumberAnimation { target: leaveShift; property: "x"; to: card.width * 0.35; duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                NumberAnimation { target: card; property: "opacity"; to: 0; duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
            }
            ScriptAction { script: NotificationService.dismiss(card.notification) }
        }

        RowLayout {
            id: contentRow
            anchors.fill: parent
            anchors.margins: 9
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignTop
                radius: 10
                color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.18)

                Image {
                    id: cardIcon
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    sourceSize.width: 40
                    sourceSize.height: 40
                    source: card.iconSource
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !cardIcon.visible
                    text: root.appInitial(card.notification)
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 14
                    font.weight: Font.Black
                    color: card.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: card.notification ? String(card.notification.summary || card.notification.appName || "Melding") : ""
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: mocha.text
                        elide: Text.ElideRight
                    }

                    Text {
                        text: NotificationService.relativeTime(card.notification)
                        visible: text !== ""
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 10
                        color: mocha.subtext0
                    }

                    IconButton {
                        icon: "󰅖"
                        accent: mocha.subtext0
                        onTriggered: card.leave()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        visible: text.length > 0
                        text: card.notification ? root.cleanText(card.notification.body) : ""
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 11
                        lineHeight: 1.1
                        color: mocha.subtext1
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }

                    // Afbeelding uit de melding (screenshot, albumhoes...).
                    Rectangle {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        Layout.alignment: Qt.AlignTop
                        visible: cardImage.status === Image.Ready
                        radius: 9
                        clip: true
                        color: "transparent"
                        Image {
                            id: cardImage
                            anchors.fill: parent
                            source: card.notification ? String(card.notification.image || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 112
                            sourceSize.height: 112
                            asynchronous: true
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    visible: card.visibleActions.length > 0
                    spacing: 6

                    Repeater {
                        model: card.visibleActions
                        delegate: ActionButton {
                            required property var modelData
                            label: String(modelData.text || "")
                            accent: card.accent
                            onTriggered: {
                                modelData.invoke();
                                card.leave();
                            }
                        }
                    }
                }
            }
        }

        HoverHandler {
            id: cardHover
            cursorShape: card.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        // Klik op de kaart = de standaardactie van de app (meestal: openen).
        TapHandler {
            acceptedButtons: Qt.LeftButton
            enabled: card.hasDefault
            onTapped: {
                NotificationService.invokeDefault(card.notification);
                card.leave();
            }
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: card.leave()
        }
    }

    component HeaderButton: Rectangle {
        id: buttonRoot
        property string icon: ""
        property string tooltip: ""
        property color accent: mocha.text
        signal triggered()

        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: 9
        opacity: enabled ? 1.0 : 0.35
        color: headerMouse.containsMouse && enabled
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
            : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.24)
        border.width: 1
        border.color: headerMouse.containsMouse && enabled
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.42)
            : root.subtleBorder

        Text {
            anchors.centerIn: parent
            text: buttonRoot.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 15
            color: buttonRoot.accent
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: buttonRoot.enabled
            onClicked: buttonRoot.triggered()
        }
    }

    component IconButton: Rectangle {
        id: buttonRoot
        property string icon: ""
        property color accent: mocha.text
        signal triggered()

        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: 7
        color: iconMouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.16)
            : "transparent"

        Text {
            anchors.centerIn: parent
            text: buttonRoot.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 13
            color: buttonRoot.accent
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: buttonRoot.triggered()
        }
    }

    component ActionButton: Rectangle {
        id: buttonRoot
        property string label: ""
        property color accent: mocha.blue
        signal triggered()

        width: actionLabel.implicitWidth + 18
        height: 26
        radius: 8
        color: actionMouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.20)
            : Qt.rgba(accent.r, accent.g, accent.b, 0.11)
        border.width: 1
        border.color: Qt.rgba(accent.r, accent.g, accent.b, actionMouse.containsMouse ? 0.44 : 0.24)

        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: buttonRoot.label
            font.family: ThemeConfig.uiFont
            font.pixelSize: 11
            font.weight: Font.Bold
            color: buttonRoot.accent
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: buttonRoot.triggered()
        }
    }
}
