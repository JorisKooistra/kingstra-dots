import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../clock"
import "../monitors"

Item {
    id: root
    required property var shell
    required property var surface
    required property var mocha
    readonly property int edgeInset: shell.edgeAttachedBar ? shell.s(10) : 0
    readonly property bool flattenScreenEdgeCorners: shell.edgeAttachedBar
                                                     && String(shell.activeThemeName || "").toLowerCase() === "botanical"
    readonly property int panelTopLeftRadius: flattenScreenEdgeCorners && (shell.isTopBar || shell.isLeftBar) ? 0 : surface.panelRadius
    readonly property int panelTopRightRadius: flattenScreenEdgeCorners && (shell.isTopBar || shell.isRightBar) ? 0 : surface.panelRadius
    readonly property int panelBottomLeftRadius: flattenScreenEdgeCorners && (shell.isBottomBar || shell.isLeftBar) ? 0 : surface.panelRadius
    readonly property int panelBottomRightRadius: flattenScreenEdgeCorners && (shell.isBottomBar || shell.isRightBar) ? 0 : surface.panelRadius
    readonly property bool cyberContinuousLine: surface.continuousBarMode
                                               && String(shell.activeThemeName || "").toLowerCase() === "cyber"
    readonly property bool cyberCenterFeature: String(shell.activeThemeName || "").toLowerCase() === "cyber"
                                             && shell.isTopBar
    readonly property bool cyberChrome: String(shell.activeThemeName || "").toLowerCase() === "cyber"
    readonly property color cyberCenterColor: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.88)
    readonly property color cyberCenterHoverColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.94)
    readonly property color cyberCenterBorderColor: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.64)
    readonly property color cyberCenterBorderHoverColor: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.78)
    readonly property color cyberCenterInnerLineColor: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.20)
    readonly property color cyberCenterAccentColor: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.56)
    readonly property color cyberCenterDividerColor: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.48)
    readonly property color cyberWeatherTempOnColor: Qt.lighter(mocha.peach, 1.15)
    readonly property color cyberWeatherTempOffColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.20)
    readonly property color cyberModuleColor: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.10)
    readonly property color cyberModuleHoverColor: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.16)
    readonly property color cyberModuleBorderColor: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.24)
    readonly property color cyberModuleBorderHoverColor: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.48)
    readonly property color cyberModuleTickColor: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.52)
    readonly property color cyberWorkspaceActiveColor: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.88)
    readonly property color cyberWorkspaceOccupiedColor: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.18)
    readonly property real cyberCenterScale: cyberCenterFeature ? 1.6 : 1.0
    readonly property int cyberWindowUnderhang: Number(shell.cyberUnderhang || 0)
    readonly property int cyberRailCenterOffset: cyberCenterFeature ? -Math.round(cyberWindowUnderhang * 0.5) : 0
    readonly property int cyberCenterPaddingY: cyberCenterFeature ? shell.s(8) : 0
    readonly property int cyberCenterBodyHeight: shell.barHeight
    readonly property int cyberSideYOffset: cyberRailCenterOffset
    readonly property int cyberSideModuleHeight: shell.barHeight
    readonly property color rightGroupColor: surface.continuousBarMode
                                            ? (cyberContinuousLine
                                                ? cyberModuleColor
                                                : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.42))
                                            : surface.panelColor
    readonly property color rightGroupBorderColor: surface.continuousBarMode
                                                  ? (cyberContinuousLine
                                                        ? cyberModuleBorderColor
                                                        : Qt.rgba(mocha.overlay1.r, mocha.overlay1.g, mocha.overlay1.b, 0.48))
                                                  : surface.panelBorderColor

                Rectangle {
                    id: centerBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.cyberCenterFeature ? 0 : Math.round((parent.height - height) / 2)
                    property bool isHovered: centerMouse.containsMouse
                    color: root.cyberCenterFeature
                           ? (isHovered ? root.cyberCenterHoverColor : root.cyberCenterColor)
                           : (isHovered ? surface.panelHoverColor : surface.panelColor)
                    radius: surface.panelRadius
                    topLeftRadius: root.panelTopLeftRadius
                    topRightRadius: root.panelTopRightRadius
                    bottomLeftRadius: root.panelBottomLeftRadius
                    bottomRightRadius: root.panelBottomRightRadius
                    border.width: 1
                    border.color: root.cyberCenterFeature
                                  ? (isHovered ? root.cyberCenterBorderHoverColor : root.cyberCenterBorderColor)
                                  : (isHovered ? surface.panelBorderHoverColor : surface.panelBorderColor)
                    height: root.cyberCenterFeature
                            ? Math.max(shell.barHeight, centerLayout.implicitHeight + (root.cyberCenterPaddingY * 2))
                            : root.cyberCenterBodyHeight
                    
                    width: centerLayout.implicitWidth + (root.cyberCenterFeature ? shell.s(42) : shell.s(36))
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                    
                    // Staggered Center Transition
                    property bool showLayout: false
                    opacity: showLayout ? 1 : 0
                    transform: Translate {
                        y: centerBox.showLayout ? 0 : shell.s(-30)
                        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    }

                    Timer {
                        running: shell.isStartupReady
                        interval: 150
                        onTriggered: centerBox.showLayout = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    // Hover Scaling
                    scale: isHovered ? 1.03 : 1.0
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                    Behavior on color { ColorAnimation { duration: 250 } }

                    Rectangle {
                        visible: root.cyberCenterFeature
                        anchors.fill: parent
                        anchors.margins: shell.s(4)
                        radius: Math.max(1, parent.radius - shell.s(2))
                        color: "transparent"
                        border.width: 1
                        border.color: root.cyberCenterInnerLineColor
                    }

                    Rectangle {
                        visible: root.cyberCenterFeature
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: shell.s(4)
                        width: Math.min(parent.width - shell.s(52), shell.s(170))
                        height: 1
                        color: root.cyberCenterAccentColor
                    }

                    MouseArea {
                        id: centerMouse
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: parent.height
                        hoverEnabled: true
                        onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])
                    }

                    // Using RowLayout to perfectly align children to vertical center naturally
                    RowLayout {
                        id: centerLayout
                        anchors.centerIn: parent
                        spacing: root.cyberCenterFeature ? shell.s(16) : shell.s(24)

                        // Clockbox
                        Item {
                            implicitWidth: clockLoader.implicitWidth
                            implicitHeight: clockLoader.implicitHeight

                            Loader {
                                id: clockLoader
                                anchors.centerIn: parent
                                sourceComponent: {
                                    let style = String(shell.clockStyle || "digital").toLowerCase();
                                    if (style === "analog") return analogClockComponent;
                                    if (style === "hybrid") return hybridClockComponent;
                                    return digitalClockComponent;
                                }
                            }

                            Component {
                                id: digitalClockComponent
                                DigitalClock {
                                    shell: root.shell
                                    mocha: root.mocha
                                    cyberScale: root.cyberCenterFeature ? 1.36 : 1.0
                                }
                            }

                            Component {
                                id: analogClockComponent
                                AnalogClock {
                                    shell: root.shell
                                    mocha: root.mocha
                                    showSecondHand: false
                                }
                            }

                            Component {
                                id: hybridClockComponent
                                RowLayout {
                                    spacing: shell.s(8)

                                    AnalogClock {
                                        shell: root.shell
                                        mocha: root.mocha
                                        showSecondHand: false
                                    }

                                    Text {
                                        text: shell.timeStr
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

                        Item {
                            visible: root.cyberCenterFeature
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: shell.s(10)
                            Layout.preferredHeight: shell.s(48)

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: parent.height
                                color: root.cyberCenterDividerColor
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 0
                                width: shell.s(5)
                                height: shell.s(2)
                                color: root.cyberCenterDividerColor
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                width: shell.s(5)
                                height: shell.s(2)
                                color: root.cyberCenterDividerColor
                            }
                        }

                        // Weatherbox
                        RowLayout {
                            spacing: shell.s(8)
                            Text { 
                                text: shell.weatherIcon; 
                                Layout.alignment: Qt.AlignVCenter;
                                font.family: "Iosevka Nerd Font"; 
                                font.pixelSize: shell.s(24); 
                                color: Qt.tint(shell.weatherHex, Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.4)) 
                            }
                            Item {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: weatherTempLoader.implicitWidth
                                implicitHeight: weatherTempLoader.implicitHeight

                                Loader {
                                    id: weatherTempLoader
                                    anchors.centerIn: parent
                                    sourceComponent: root.cyberCenterFeature ? cyberWeatherTempComponent : defaultWeatherTempComponent
                                }

                                Component {
                                    id: cyberWeatherTempComponent
                                    SevenSegmentText {
                                        text: String(shell.weatherTemp || "--°C")
                                        glyphWidth: shell.s(12)
                                        glyphHeight: shell.s(20)
                                        glyphSpacing: shell.s(2)
                                        segmentOnColor: root.cyberWeatherTempOnColor
                                        segmentOffColor: root.cyberWeatherTempOffColor
                                    }
                                }

                                Component {
                                    id: defaultWeatherTempComponent
                                    Text {
                                        text: shell.weatherTemp
                                        font.family: shell.monoFontFamily
                                        font.pixelSize: shell.s(17)
                                        font.weight: shell.themeFontWeight
                                        font.letterSpacing: shell.themeLetterSpacing
                                        color: mocha.peach
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------------- LEFT ----------------
                RowLayout {
                    id: leftLayout
                    anchors.left: parent.left
                    anchors.leftMargin: root.edgeInset
                    anchors.right: centerBox.left  // Hard boundary to prevent overlaps
                    anchors.rightMargin: shell.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: root.cyberSideYOffset
                    spacing: shell.s(4) 

                    // Staggered Main Transition
                    property bool showLayout: false
                    opacity: showLayout ? 1 : 0
                    transform: Translate {
                        x: leftLayout.showLayout ? 0 : shell.s(-30)
                        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    }
                    
                    Timer {
                        running: shell.isStartupReady
                        interval: 10
                        onTriggered: leftLayout.showLayout = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    property int moduleHeight: root.cyberSideModuleHeight

                    // Search 
                    Rectangle {
                        property bool isHovered: searchMouse.containsMouse
                        color: root.cyberChrome
                               ? (isHovered ? root.cyberModuleHoverColor : root.cyberModuleColor)
                               : (isHovered ? surface.panelHoverColor : surface.panelColor)
                        radius: surface.panelRadius
                        topLeftRadius: root.panelTopLeftRadius
                        topRightRadius: root.panelTopRightRadius
                        bottomLeftRadius: root.panelBottomLeftRadius
                        bottomRightRadius: root.panelBottomRightRadius
                        border.width: 1
                        border.color: root.cyberChrome
                                      ? (isHovered ? root.cyberModuleBorderHoverColor : root.cyberModuleBorderColor)
                                      : (isHovered ? surface.panelBorderHoverColor : surface.panelBorderColor)
                        Layout.preferredHeight: parent.moduleHeight; Layout.preferredWidth: shell.barHeight
                        
                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰍉"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(24)
                            color: parent.isHovered ? mocha.blue : mocha.text
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        Rectangle {
                            visible: root.cyberChrome
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: shell.s(4)
                            width: parent.isHovered ? shell.s(18) : shell.s(10)
                            height: 1
                            color: root.cyberModuleTickColor
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: searchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(["bash", "-c", "walker"])
                        }
                    }

                    // Notifications
                    Rectangle {
                        visible: shell.moduleList.includes("notifications")
                        property bool isHovered: notifMouse.containsMouse
                        color: root.cyberChrome
                               ? (isHovered ? root.cyberModuleHoverColor : root.cyberModuleColor)
                               : (isHovered ? surface.panelHoverColor : surface.panelColor)
                        radius: surface.panelRadius
                        topLeftRadius: root.panelTopLeftRadius
                        topRightRadius: root.panelTopRightRadius
                        bottomLeftRadius: root.panelBottomLeftRadius
                        bottomRightRadius: root.panelBottomRightRadius
                        border.width: 1
                        border.color: root.cyberChrome
                                      ? (isHovered ? root.cyberModuleBorderHoverColor : root.cyberModuleBorderColor)
                                      : (isHovered ? surface.panelBorderHoverColor : surface.panelBorderColor)
                        Layout.preferredHeight: parent.moduleHeight; Layout.preferredWidth: shell.barHeight
                        
                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                        
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(18)
                            color: parent.isHovered ? mocha.yellow : mocha.text
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        Rectangle {
                            visible: root.cyberChrome
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: shell.s(4)
                            width: parent.isHovered ? shell.s(18) : shell.s(10)
                            height: 1
                            color: root.cyberModuleTickColor
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: notifMouse
                            anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) Quickshell.execDetached(["swaync-client", "-t", "-sw"]);
                                if (mouse.button === Qt.RightButton) Quickshell.execDetached(["swaync-client", "-d"]);
                            }
                        }
                    }

                    // Workspaces
                    Rectangle {
                        color: root.cyberChrome ? root.cyberModuleColor : surface.panelColor
                        radius: surface.panelRadius
                        topLeftRadius: root.panelTopLeftRadius
                        topRightRadius: root.panelTopRightRadius
                        bottomLeftRadius: root.panelBottomLeftRadius
                        bottomRightRadius: root.panelBottomRightRadius
                        border.width: 1
                        border.color: root.cyberChrome ? root.cyberModuleBorderColor : surface.panelBorderColor
                        Layout.preferredHeight: parent.moduleHeight
                        clip: true

                        property real targetWidth: workspacesModel.count > 0 ? wsLayout.width + shell.s(20) : 0
                        Layout.preferredWidth: targetWidth
                        visible: targetWidth > 0 && shell.moduleList.includes("workspaces")
                        opacity: workspacesModel.count > 0 ? 1 : 0
                        
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Rectangle {
                            visible: root.cyberChrome
                            anchors.left: parent.left
                            anchors.leftMargin: shell.s(10)
                            anchors.right: parent.right
                            anchors.rightMargin: shell.s(10)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: shell.s(4)
                            height: 1
                            color: root.cyberModuleTickColor
                            opacity: 0.52
                        }

                        // Using standard Row completely removes internal width sizing bugs
                        Row {
                            id: wsLayout
                            anchors.centerIn: parent
                            spacing: shell.s(6)
                            
                            Repeater {
                                model: workspacesModel
                                delegate: Rectangle {
                                    id: wsPill
                                    property bool isHovered: wsPillMouse.containsMouse
                                    
                                    // Mapped dynamically from the ListModel
                                    property string stateLabel: model.wsState
                                    property string wsName: model.wsId
                                    
                                    property real targetWidth: shell.s(32)
                                    width: targetWidth
                                    Behavior on targetWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                    
                                    height: shell.s(32); radius: surface.innerPillRadius
                                    
                                    color: stateLabel === "active"
                                            ? (root.cyberChrome ? root.cyberWorkspaceActiveColor : mocha.mauve)
                                            : (isHovered 
                                                ? (root.cyberChrome ? Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.26) : Qt.rgba(mocha.overlay0.r, mocha.overlay0.g, mocha.overlay0.b, 0.9))
                                                : (stateLabel === "occupied"
                                                    ? (root.cyberChrome ? root.cyberWorkspaceOccupiedColor : Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.9))
                                                    : "transparent"))

                                    scale: isHovered && stateLabel !== "active" ? 1.08 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                    
                                    property bool initAnimTrigger: false
                                    opacity: initAnimTrigger ? 1 : 0
                                    transform: Translate {
                                        y: wsPill.initAnimTrigger ? 0 : shell.s(15)
                                        Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                                    }

                                    Component.onCompleted: {
                                        if (!shell.startupCascadeFinished) {
                                            animTimer.interval = index * 60;
                                            animTimer.start();
                                        } else {
                                            initAnimTrigger = true;
                                        }
                                    }

                                    Timer {
                                        id: animTimer
                                        running: false
                                        repeat: false
                                        onTriggered: wsPill.initAnimTrigger = true
                                    }
                                    
                                    Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 250 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: wsName
                                        font.family: shell.monoFontFamily
                                        font.pixelSize: shell.s(14)
                                        font.weight: stateLabel === "active" ? Font.Black : (stateLabel === "occupied" ? Font.Bold : Font.Medium)
                                        font.letterSpacing: shell.themeLetterSpacing
                                        
                                        color: stateLabel === "active" 
                                                ? (root.cyberChrome ? mocha.base : mocha.crust)
                                                : (isHovered 
                                                    ? (root.cyberChrome ? mocha.text : mocha.crust)
                                                    : (stateLabel === "occupied" ? mocha.text : mocha.overlay0))
                                        
                                        Behavior on color { ColorAnimation { duration: 250 } }
                                    }
                                    MouseArea {
                                        id: wsPillMouse
                                        hoverEnabled: true
                                        anchors.fill: parent
                                        onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + wsName])
                                    }
                                }
                            }
                        }
                    }            

                    // Media Player
                    Rectangle {
                        id: mediaBox
                        color: root.cyberChrome ? root.cyberModuleColor : surface.panelColor
                        radius: surface.panelRadius
                        topLeftRadius: root.panelTopLeftRadius
                        topRightRadius: root.panelTopRightRadius
                        bottomLeftRadius: root.panelBottomLeftRadius
                        bottomRightRadius: root.panelBottomRightRadius
                        border.width: 1
                        border.color: root.cyberChrome ? root.cyberModuleBorderColor : surface.panelBorderColor
                        Layout.preferredHeight: parent.moduleHeight
                        clip: true

                        property bool isMediaMode: shell.activeMode === "media"
                        property real targetWidth: shell.isMediaActive ? mediaLayoutContainer.width + shell.s(24) : 0
                        Layout.maximumWidth: isMediaMode ? shell.s(220) : targetWidth
                        Layout.preferredWidth: targetWidth

                        visible: (targetWidth > 0 || opacity > 0) && shell.moduleList.includes("media_controls")
                        opacity: shell.isMediaActive ? 1.0 : 0.0

                        Behavior on targetWidth { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 400 } }

                        Rectangle {
                            visible: root.cyberChrome
                            anchors.left: parent.left
                            anchors.leftMargin: shell.s(10)
                            anchors.right: parent.right
                            anchors.rightMargin: shell.s(10)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: shell.s(4)
                            height: 1
                            color: root.cyberModuleTickColor
                            opacity: shell.isMediaActive ? 0.62 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                        }
                        
                        Item {
                            id: mediaLayoutContainer
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: shell.s(12)
                            height: parent.height
                            width: innerMediaLayout.width
                            
                            opacity: shell.isMediaActive ? 1.0 : 0.0
                            transform: Translate { 
                                x: shell.isMediaActive ? 0 : shell.s(-20) 
                                Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
                            }
                            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                            Row {
                                id: innerMediaLayout
                                anchors.verticalCenter: parent.verticalCenter
                                // Dynamically reduce spacing between song info and controls on smaller screens
                                spacing: shell.width < 1920 ? shell.s(8) : shell.s(16)
                                
                                MouseArea {
                                    id: mediaInfoMouse
                                    width: infoLayout.width
                                    height: innerMediaLayout.height
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle music"])
                                    
                                    Row {
                                        id: infoLayout
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: shell.s(10)
                                        
                                        scale: mediaInfoMouse.containsMouse ? 1.02 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                        Rectangle {
                                            width: shell.s(32); height: shell.s(32); radius: shell.s(8); color: mocha.surface1
                                            border.width: shell.musicData.status === "Playing" ? 1 : 0
                                            border.color: mocha.mauve
                                            clip: true
                                            Image { 
                                                anchors.fill: parent; 
                                                source: shell.musicData.artUrl || ""; 
                                                fillMode: Image.PreserveAspectCrop 
                                            }
                                            
                                            Rectangle {
                                                anchors.fill: parent
                                                color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.2)
                                            }
                                        }
                                        Column {
                                            spacing: -2
                                            anchors.verticalCenter: parent.verticalCenter
                                            // Make column explicitly sized to enforce elide truncating on text
                                            property real maxColWidth: shell.width < 1920 ? shell.s(120) : shell.s(180)
                                            width: maxColWidth 
                                            
                                            Text {
                                                text: shell.musicData.title;
                                                font.family: "JetBrains Mono";
                                                font.weight: Font.Black;
                                                font.pixelSize: mediaBox.isMediaMode ? shell.s(11) : shell.s(13);
                                                color: mocha.text;
                                                width: Math.min(parent.width, mediaBox.isMediaMode ? shell.s(120) : shell.s(200))
                                                elide: Text.ElideRight;
                                            }
                                            Text { 
                                                text: shell.musicData.timeStr; 
                                                font.family: "JetBrains Mono"; 
                                                font.weight: Font.Black; 
                                                font.pixelSize: shell.s(10); 
                                                color: mocha.subtext0;
                                                width: parent.width
                                                elide: Text.ElideRight;
                                            }
                                        }
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: shell.width < 1920 ? shell.s(4) : shell.s(8)
                                    Item { 
                                        width: shell.s(24); height: shell.s(24); 
                                        Text { 
                                            anchors.centerIn: parent; text: "󰒮"; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(26); 
                                            color: prevMouse.containsMouse ? mocha.text : mocha.overlay2; 
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            scale: prevMouse.containsMouse ? 1.1 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                        }
                                        MouseArea { id: prevMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "previous"]); musicForceRefresh.running = true; } } 
                                    }
                                    Item { 
                                        width: shell.s(28); height: shell.s(28); 
                                        Text { 
                                            anchors.centerIn: parent; text: shell.musicData.status === "Playing" ? "󰏤" : "󰐊"; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(30); 
                                            color: playMouse.containsMouse ? mocha.green : mocha.text; 
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            scale: playMouse.containsMouse ? 1.15 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                        }
                                        MouseArea { id: playMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "play-pause"]); musicForceRefresh.running = true; } } 
                                    }
                                    Item { 
                                        width: shell.s(24); height: shell.s(24); 
                                        Text { 
                                            anchors.centerIn: parent; text: "󰒭"; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(26); 
                                            color: nextMouse.containsMouse ? mocha.text : mocha.overlay2; 
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            scale: nextMouse.containsMouse ? 1.1 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                        }
                                        MouseArea { id: nextMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "next"]); musicForceRefresh.running = true; } } 
                                    }
                                }
                            }
                        }
                    }
                    
                    // DYNAMIC SPACER: Pushes everything tightly to the left side
                    Item { Layout.fillWidth: true } 
                }

                // ---------------- RIGHT ----------------
                RowLayout {
                    id: rightLayout
                    anchors.right: parent.right
                    anchors.rightMargin: root.edgeInset
                    anchors.left: centerBox.right // Hard boundary to prevent overlaps
                    anchors.leftMargin: shell.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: root.cyberSideYOffset
                    spacing: shell.s(4)

                    // Staggered Right Transition
                    property bool showLayout: false
                    opacity: showLayout ? 1 : 0
                    transform: Translate {
                        x: rightLayout.showLayout ? 0 : shell.s(30)
                        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    }
                    
                    Timer {
                        running: shell.isStartupReady && shell.isDataReady
                        interval: 250
                        onTriggered: rightLayout.showLayout = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    // Dynamic Spacer to gently push the tray and system pills completely to the right edge
                    Item { Layout.fillWidth: true } 

                    // Dedicated System Tray Pill
                    Rectangle {
                        Layout.preferredHeight: root.cyberSideModuleHeight
                        Layout.alignment: Qt.AlignVCenter
                        radius: surface.panelRadius
                        topLeftRadius: root.panelTopLeftRadius
                        topRightRadius: root.panelTopRightRadius
                        bottomLeftRadius: root.panelBottomLeftRadius
                        bottomRightRadius: root.panelBottomRightRadius
                        border.color: root.rightGroupBorderColor
                        border.width: 1
                        color: root.rightGroupColor
                        clip: true
                        
                        property real targetWidth: trayRepeater.count > 0 ? trayLayout.width + shell.s(24) : 0
                        Layout.preferredWidth: targetWidth
                        Behavior on targetWidth { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                        
                        visible: targetWidth > 0
                        opacity: targetWidth > 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Rectangle {
                            visible: root.cyberChrome
                            anchors.left: parent.left
                            anchors.leftMargin: shell.s(8)
                            anchors.right: parent.right
                            anchors.rightMargin: shell.s(8)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: shell.s(4)
                            height: 1
                            color: root.cyberModuleTickColor
                            opacity: 0.48
                        }

                        Row {
                            id: trayLayout
                            anchors.centerIn: parent
                            spacing: shell.s(10)

                            Repeater {
                                id: trayRepeater
                                model: SystemTray.items
                                delegate: Image {
                                    id: trayIcon
                                    source: modelData.icon || ""
                                    fillMode: Image.PreserveAspectFit
                                    
                                    sourceSize: Qt.size(shell.s(18), shell.s(18))
                                    width: shell.s(18)
                                    height: shell.s(18)
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    property bool isHovered: trayMouse.containsMouse
                                    property bool initAnimTrigger: false
                                    opacity: initAnimTrigger ? (isHovered ? 1.0 : 0.8) : 0.0
                                    scale: initAnimTrigger ? (isHovered ? 1.15 : 1.0) : 0.0

                                    Component.onCompleted: {
                                        if (!shell.startupCascadeFinished) {
                                            trayAnimTimer.interval = index * 50;
                                            trayAnimTimer.start();
                                        } else {
                                            initAnimTrigger = true;
                                        }
                                    }
                                    Timer {
                                        id: trayAnimTimer
                                        running: false
                                        repeat: false
                                        onTriggered: trayIcon.initAnimTrigger = true
                                    }

                                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                    QsMenuAnchor {
                                        id: menuAnchor
                                        anchor.window: barWindow
                                        anchor.item: trayIcon
                                        menu: modelData.menu
                                    }

                                    MouseArea {
                                        id: trayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.LeftButton) {
                                                modelData.activate();
                                            } else if (mouse.button === Qt.MiddleButton) {
                                                modelData.secondaryActivate();
                                            } else if (mouse.button === Qt.RightButton) {
                                                if (modelData.menu) {
                                                    menuAnchor.open();
                                                } else if (typeof modelData.contextMenu === "function") {
                                                    modelData.contextMenu(mouse.x, mouse.y);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // System Elements Pill
                    Rectangle {
                        Layout.preferredHeight: root.cyberSideModuleHeight
                        Layout.alignment: Qt.AlignVCenter
                        radius: surface.panelRadius
                        topLeftRadius: root.panelTopLeftRadius
                        topRightRadius: root.panelTopRightRadius
                        bottomLeftRadius: root.panelBottomLeftRadius
                        bottomRightRadius: root.panelBottomRightRadius
                        border.color: root.rightGroupBorderColor
                        border.width: 1
                        color: root.rightGroupColor
                        clip: true
                        
                        property real targetWidth: sysLayout.width + shell.s(20)
                        Layout.preferredWidth: targetWidth
                        Layout.maximumWidth: targetWidth

                        Rectangle {
                            visible: root.cyberChrome
                            anchors.left: parent.left
                            anchors.leftMargin: shell.s(10)
                            anchors.right: parent.right
                            anchors.rightMargin: shell.s(10)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: shell.s(4)
                            height: 1
                            color: root.cyberModuleTickColor
                            opacity: 0.48
                        }

                        Row {
                            id: sysLayout
                            anchors.centerIn: parent
                            spacing: shell.s(8) 

                            property int pillHeight: shell.s(34)

                            // KB
                            Rectangle {
                                id: kbPill
                                property bool isHovered: kbMouse.containsMouse
                                color: isHovered ? surface.innerPillHoverColor : surface.innerPillColor
                                radius: surface.innerPillRadius; height: sysLayout.pillHeight;
                                clip: true

                                property real targetWidth: kbLayoutRow.width + shell.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightLayout.showLayout && !kbPill.initAnimTrigger; interval: 0; onTriggered: kbPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: kbPill.initAnimTrigger ? 0 : shell.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: kbLayoutRow; anchors.centerIn: parent; spacing: shell.s(8)
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "󰌌"; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(16); color: parent.parent.isHovered ? mocha.text : mocha.overlay2 }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: shell.kbLayout; font.family: shell.monoFontFamily; font.pixelSize: shell.s(13); font.weight: shell.themeFontWeight; font.letterSpacing: shell.themeLetterSpacing; color: mocha.text }
                                }
                                MouseArea { id: kbMouse; anchors.fill: parent; hoverEnabled: true }
                            }

                            // Package updates (Office mode)
                            Rectangle {
                                id: updatesPill
                                visible: shell.moduleList.includes("updates")
                                property bool isHovered: updatesMouse.containsMouse
                                property int updates: Math.max(0, parseInt(shell.updateCount) || 0)
                                radius: surface.innerPillRadius
                                height: sysLayout.pillHeight
                                clip: true
                                color: isHovered ? surface.innerPillHoverColor : surface.innerPillColor

                                Rectangle {
                                    anchors.fill: parent
                                    radius: surface.innerPillRadius
                                    opacity: updatesPill.updates > 0 ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: mocha.yellow }
                                        GradientStop { position: 1.0; color: Qt.lighter(mocha.peach, 1.2) }
                                    }
                                }

                                property real targetWidth: updatesLayoutRow.width + shell.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightLayout.showLayout && !updatesPill.initAnimTrigger; interval: 25; onTriggered: updatesPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: updatesPill.initAnimTrigger ? 0 : shell.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row {
                                    id: updatesLayoutRow
                                    anchors.centerIn: parent
                                    spacing: shell.s(8)

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰚰"
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: shell.s(16)
                                        color: updatesPill.updates > 0 ? mocha.base : mocha.subtext0
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: updatesPill.updates.toString()
                                        font.family: shell.monoFontFamily
                                        font.pixelSize: shell.s(13)
                                        font.weight: shell.themeFontWeight
                                        font.letterSpacing: shell.themeLetterSpacing
                                        color: updatesPill.updates > 0 ? mocha.base : mocha.text
                                    }
                                }

                                MouseArea {
                                    id: updatesMouse
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    onClicked: shell.openUpdatesTerminal()
                                }
                            }

                            // CPU Temperatuur (Gaming mode)
                            CpuTemp {
                                id: cpuTempPill
                                visible: shell.moduleList.includes("cpu_temp")
                                mocha: root.mocha
                                pillHeight: sysLayout.pillHeight
                                radius: surface.innerPillRadius
                            }

                            // GPU Temperatuur (Gaming mode)
                            GpuTemp {
                                id: gpuTempPill
                                visible: shell.moduleList.includes("gpu_temp")
                                mocha: root.mocha
                                pillHeight: sysLayout.pillHeight
                                radius: surface.innerPillRadius
                            }

                            // RAM Gebruik (Gaming mode)
                            RamUsage {
                                id: ramUsagePill
                                visible: shell.moduleList.includes("ram_usage")
                                mocha: root.mocha
                                pillHeight: sysLayout.pillHeight
                                radius: surface.innerPillRadius
                            }

                            // WiFi
                            Rectangle {
                                id: wifiPill
                                visible: shell.moduleList.includes("network")
                                property bool isHovered: wifiMouse.containsMouse
                                radius: surface.innerPillRadius; height: sysLayout.pillHeight; 
                                color: isHovered ? surface.innerPillHoverColor : surface.innerPillColor
                                clip: true
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: surface.innerPillRadius
                                    opacity: shell.isWifiOn ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: mocha.blue }
                                        GradientStop { position: 1.0; color: Qt.lighter(mocha.blue, 1.3) }
                                    }
                                }

                                property real targetWidth: wifiLayoutRow.width + shell.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                                
                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightLayout.showLayout && !wifiPill.initAnimTrigger; interval: 50; onTriggered: wifiPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: wifiPill.initAnimTrigger ? 0 : shell.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: wifiLayoutRow; anchors.centerIn: parent; spacing: shell.s(8)
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: shell.wifiIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(16); color: shell.isWifiOn ? mocha.base : mocha.subtext0 }
                                    Text { 
                                        id: wifiText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shell.sysPollerLoaded ? (shell.isWifiOn ? (shell.wifiSsid !== "" ? shell.wifiSsid : "On") : "Off") : ""
                                        visible: text !== ""
                                        font.family: shell.monoFontFamily; font.pixelSize: shell.s(13); font.weight: shell.themeFontWeight; font.letterSpacing: shell.themeLetterSpacing;
                                        color: shell.isWifiOn ? mocha.base : mocha.text; 
                                        width: Math.min(implicitWidth, shell.s(100)); elide: Text.ElideRight 
                                    }
                                }
                                MouseArea { id: wifiMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network wifi"]) }
                            }

                            // Bluetooth
                            Rectangle {
                                id: btPill
                                visible: shell.moduleList.includes("bluetooth")
                                property bool isHovered: btMouse.containsMouse
                                radius: surface.innerPillRadius; height: sysLayout.pillHeight
                                clip: true
                                color: isHovered ? surface.innerPillHoverColor : surface.innerPillColor
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: surface.innerPillRadius
                                    opacity: shell.isBtOn ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: mocha.mauve }
                                        GradientStop { position: 1.0; color: Qt.lighter(mocha.mauve, 1.3) }
                                    }
                                }

                                property real targetWidth: btLayoutRow.width + shell.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightLayout.showLayout && !btPill.initAnimTrigger; interval: 100; onTriggered: btPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: btPill.initAnimTrigger ? 0 : shell.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: btLayoutRow; anchors.centerIn: parent; spacing: shell.s(8)
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: shell.btIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(16); color: shell.isBtOn ? mocha.base : mocha.subtext0 }
                                    Text { 
                                        id: btText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shell.sysPollerLoaded ? shell.btDevice : ""
                                        visible: text !== ""; 
                                        font.family: shell.monoFontFamily; font.pixelSize: shell.s(13); font.weight: shell.themeFontWeight; font.letterSpacing: shell.themeLetterSpacing;
                                        color: shell.isBtOn ? mocha.base : mocha.text; 
                                        width: Math.min(implicitWidth, shell.s(100)); elide: Text.ElideRight 
                                    }
                                }
                                MouseArea { id: btMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network bt"]) }
                            }

                            // Volume
                            Rectangle {
                                id: volPill
                                visible: shell.moduleList.includes("volume")
                                property bool isHovered: volMouse.containsMouse
                                color: isHovered ? surface.innerPillHoverColor : surface.innerPillColor
                                radius: surface.innerPillRadius; height: sysLayout.pillHeight;
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: surface.innerPillRadius
                                    opacity: shell.isSoundActive ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: mocha.peach }
                                        GradientStop { position: 1.0; color: Qt.lighter(mocha.peach, 1.3) }
                                    }
                                }

                                property real targetWidth: volLayoutRow.width + shell.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightLayout.showLayout && !volPill.initAnimTrigger; interval: 150; onTriggered: volPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: volPill.initAnimTrigger ? 0 : shell.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: volLayoutRow; anchors.centerIn: parent; spacing: shell.s(8)
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shell.volIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(16); 
                                        color: shell.isSoundActive ? mocha.base : mocha.subtext0 
                                    }
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shell.volPercent; 
                                        font.family: shell.monoFontFamily; font.pixelSize: shell.s(13); font.weight: shell.themeFontWeight; font.letterSpacing: shell.themeLetterSpacing;
                                        color: shell.isSoundActive ? mocha.base : mocha.text; 
                                    }
                                }
                                MouseArea {
                                    id: volMouse
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle volume"])
                                    onWheel: (wheel) => {
                                        shell.handleVolumeWheel(wheel.angleDelta.y);
                                        wheel.accepted = true;
                                    }
                                }
                            }

                            // Helderheid (Media mode)
                            BrightnessControl {
                                id: brightnessPill
                                visible: shell.moduleList.includes("brightness")
                                mocha: root.mocha
                                pillHeight: sysLayout.pillHeight
                                radius: surface.innerPillRadius
                            }

                            // Game Launcher (Gaming mode)
                            GameLauncher {
                                id: gameLauncherPill
                                visible: shell.moduleList.includes("game_launcher")
                                mocha: root.mocha
                                pillHeight: sysLayout.pillHeight
                                radius: surface.innerPillRadius
                            }

                            // Battery
                            Rectangle {
                                id: batPill
                                visible: shell.moduleList.includes("battery")
                                property bool isHovered: batMouse.containsMouse
                                color: isHovered ? surface.innerPillHoverColor : surface.innerPillColor;
                                radius: surface.innerPillRadius; height: sysLayout.pillHeight;
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: surface.innerPillRadius
                                    opacity: (shell.isCharging || shell.batCap <= 20) ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: shell.batDynamicColor; Behavior on color { ColorAnimation { duration: 300 } } }
                                        GradientStop { position: 1.0; color: Qt.lighter(shell.batDynamicColor, 1.3); Behavior on color { ColorAnimation { duration: 300 } } }
                                    }
                                }

                                property real targetWidth: batLayoutRow.width + shell.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightLayout.showLayout && !batPill.initAnimTrigger; interval: 200; onTriggered: batPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: batPill.initAnimTrigger ? 0 : shell.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: batLayoutRow; anchors.centerIn: parent; spacing: shell.s(8)
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shell.batIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(16); 
                                        color: (shell.isCharging || shell.batCap <= 20) ? mocha.base : shell.batDynamicColor
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shell.batPercent; font.family: shell.monoFontFamily; font.pixelSize: shell.s(13); font.weight: shell.themeFontWeight; font.letterSpacing: shell.themeLetterSpacing;
                                        color: (shell.isCharging || shell.batCap <= 20) ? mocha.base : shell.batDynamicColor
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                }
                                MouseArea { id: batMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle battery"]) }
                            }
                        }
                    }
                }
}
