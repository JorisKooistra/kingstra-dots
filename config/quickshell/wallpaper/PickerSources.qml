import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: dialog

    required property var controller
    required property var colors

    color: Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.88)

    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(760, dialog.width - 48)
        height: Math.min(700, dialog.height - 32)
        radius: 18
        color: dialog.colors.surfaceContainer
        border.color: dialog.colors.primary

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                PickerText {
                    Layout.fillWidth: true
                    text: "Wallpaperbronnen koppelen"
                    color: dialog.colors.text
                    font.pixelSize: 22
                    font.bold: true
                }

                PickerButton {
                    objectName: "sources-close"
                    colors: dialog.colors
                    text: "×"
                    onClicked: dialog.controller.credentialsOpen = false
                }

            }

            PickerText {
                Layout.fillWidth: true
                text: "Sleutels worden alleen lokaal bewaard. Je hoeft ze niet in de chat te plakken."
                wrapMode: Text.WordWrap
                color: dialog.colors.onSurfaceVariant
            }

            ScrollView {
                id: keyScroll

                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: keyScroll.availableWidth
                    spacing: 12

                    Repeater {
                        model: dialog.controller.extraSources.filter((source) => {
                            return source.needsKey || source.optionalKey;
                        })

                        ColumnLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true

                                PickerText {
                                    text: modelData.label + (modelData.optionalKey ? " · optioneel" : "")
                                    color: dialog.colors.text
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                PickerText {
                                    text: modelData.configured ? (modelData.id === "wallhaven" && !modelData.hasLocalKey ? "Bestaande skwd-sleutel" : "Sleutel opgeslagen") : "Nog geen sleutel"
                                    color: dialog.colors.onSurfaceVariant
                                }

                                PickerButton {
                                    colors: dialog.colors
                                    text: "Sleutel aanvragen ↗"
                                    onClicked: Qt.openUrlExternally(modelData.keyUrl)
                                }

                            }

                            RowLayout {
                                Layout.fillWidth: true

                                TextField {
                                    id: entry

                                    objectName: "key-" + modelData.id
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    echoMode: TextInput.Password
                                    placeholderText: modelData.configured ? "Nieuwe sleutel invullen om te vervangen…" : "API-sleutel"
                                    color: dialog.colors.text
                                    placeholderTextColor: dialog.colors.onSurfaceVariant
                                    selectByMouse: true
                                    onAccepted: {
                                        if (text.trim() && !dialog.controller.credentialBusy) {
                                            dialog.controller.saveKey(modelData.id, text);
                                            clear();
                                        }
                                    }

                                    background: Rectangle {
                                        color: dialog.colors.surface
                                        radius: 8
                                    }

                                }

                                PickerButton {
                                    objectName: "save-key-" + modelData.id
                                    colors: dialog.colors
                                    text: "Opslaan"
                                    available: !dialog.controller.credentialBusy && !!entry.text.trim()
                                    onClicked: {
                                        dialog.controller.saveKey(modelData.id, entry.text);
                                        entry.clear();
                                    }
                                }

                                PickerButton {
                                    objectName: "remove-key-" + modelData.id
                                    colors: dialog.colors
                                    text: "Wissen"
                                    visible: modelData.configured && (modelData.id !== "wallhaven" || modelData.hasLocalKey)
                                    available: !dialog.controller.credentialBusy
                                    onClicked: dialog.controller.saveKey(modelData.id, "")
                                }

                            }

                        }

                    }

                }

            }

            PickerText {
                Layout.fillWidth: true
                text: "Pexels verstrekt momenteel geen nieuwe sleutels. Vraag bij Pixabay ook volledige API-toegang aan voor originele resoluties. De andere bronnen hebben geen sleutel nodig."
                wrapMode: Text.WordWrap
                color: dialog.colors.onSurfaceVariant
                font.pixelSize: 12
            }

            PickerText {
                Layout.fillWidth: true
                text: dialog.controller.credentialsMessage
                wrapMode: Text.WordWrap
                color: dialog.colors.text
                textFormat: Text.PlainText
            }

        }

    }

}
