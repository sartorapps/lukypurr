import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Item {
    property var track: ctrl.currentTrack
    property var spectrumData: ctrl.spectrum
    property int bandCount: 40

    Connections {
        target: ctrl
        function onCurrentTrackChanged() {
            track = ctrl.currentTrack
        }
        function onSpectrumChanged() {
            spectrumData = ctrl.spectrum
        }
    }

    function formatTime(seconds) {
        var s = Math.floor(seconds)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function getMirrorHeight(pos) {
        if (!spectrumData || spectrumData.length === 0) return 8
        var bandIndex = pos < 20 ? pos : (39 - pos)
        bandIndex = Math.min(bandIndex, spectrumData.length - 1)
        return Math.max(8, spectrumData[bandIndex] * visualizer.height * 0.65)
    }

    function getBandColor(pos) {
        var bandIndex = pos < 20 ? pos : (39 - pos)
        var ratio = bandIndex / 19.0
        var base = settingsService.gradient_color
        var r = parseInt(base.substr(1,2), 16) / 255
        var g = parseInt(base.substr(3,2), 16) / 255
        var b = parseInt(base.substr(5,2), 16) / 255
        var intensity = settingsService.gradient_intensity / 100
        var dark = 0.12 + ratio * 0.88
        return Qt.rgba(dark * r * intensity + 0.08, dark * g * intensity + 0.08, dark * b * intensity + 0.08, 1.0)
    }

    function getBandColorDark(pos) {
        var bandIndex = pos < 20 ? pos : (39 - pos)
        var ratio = bandIndex / 19.0
        var base = settingsService.gradient_color
        var r = parseInt(base.substr(1,2), 16) / 255
        var g = parseInt(base.substr(3,2), 16) / 255
        var b = parseInt(base.substr(5,2), 16) / 255
        var intensity = settingsService.gradient_intensity / 100
        var dark = 0.08 + ratio * 0.5
        return Qt.rgba(dark * r * intensity + 0.04, dark * g * intensity + 0.04, dark * b * intensity + 0.04, 1.0)
    }

    // Audio spectrum visualizer - mirrored from center
    Item {
        id: visualizer
        anchors.fill: parent
        opacity: settingsService.gradient_opacity / 100

        Repeater {
            model: bandCount

            Rectangle {
                id: spectrumBar
                x: index * (visualizer.width / bandCount) + 1
                width: (visualizer.width / bandCount) - 2
                radius: 3

                property real targetHeight: getMirrorHeight(index)

                height: targetHeight
                anchors.bottom: parent.bottom

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: getBandColor(index) }
                    GradientStop { position: 0.5; color: getBandColorDark(index) }
                    GradientStop { position: 1.0; color: "#0a0a0a" }
                }

                Behavior on height {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }

        // Mirror reflection below
        Repeater {
            model: bandCount

            Rectangle {
                x: index * (visualizer.width / bandCount) + 1
                width: (visualizer.width / bandCount) - 2
                radius: 3
                height: getMirrorHeight(index) * 0.3
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 0
                opacity: 0.3

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: getBandColorDark(index) }
                    GradientStop { position: 1.0; color: "transparent" }
                }

                Behavior on height {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 20

        Item { Layout.fillHeight: true; Layout.maximumHeight: 30 }

        RowLayout {
            Layout.fillWidth: true
            spacing: 50

            Item { Layout.fillWidth: true }

            Item {
                Layout.preferredWidth: Math.min(root.width * 0.3, 280)
                Layout.preferredHeight: Layout.preferredWidth

                Rectangle {
                    id: coverBg
                    anchors.fill: parent
                    radius: 12
                    color: theme.bg_card
                }

                Image {
                    id: coverImage
                    anchors.fill: parent
                    source: track.thumbnail || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                Rectangle {
                    id: coverMask
                    anchors.fill: parent
                    radius: 12
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: coverImage
                    maskSource: coverMask
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u{1F3B5}"
                    font.pixelSize: 64
                    visible: coverImage.status !== Image.Ready
                    opacity: 0.3
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: "transparent"
                    border.color: theme.border
                    border.width: 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 400
                spacing: 16

                Item { Layout.preferredHeight: 10 }

                Text {
                    text: track.title || "No track playing"
                    color: theme.text_primary
                    font.pixelSize: 28
                    font.bold: true
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    text: track.artist || ""
                    color: theme.text_secondary
                    font.pixelSize: 18
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: track.duration ? track.duration : ""
                    color: theme.text_muted
                    font.pixelSize: 14
                    visible: track.duration !== ""
                }

                Item { Layout.preferredHeight: 12 }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#2A2A2A"
                }

                // Volume control
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: playerService.volume > 50 ? "\u{1F50A}" : (playerService.volume > 0 ? "\u{1F509}" : "\u{1F507}")
                        color: theme.text_muted
                        font.pixelSize: 16
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: theme.border

                            Rectangle {
                                width: (playerService.volume / 100) * parent.width
                                height: parent.height
                                radius: 2
                                color: pVolMouse.containsMouse ? theme.accent_hover : theme.accent
                            }

                            Rectangle {
                                x: Math.min((playerService.volume / 100) * parent.width - width / 2, parent.width - width / 2)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12
                                height: 12
                                radius: 6
                                color: theme.text_primary
                                visible: pVolMouse.containsMouse || pVolMouse.pressed
                            }
                        }

                        MouseArea {
                            id: pVolMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function setVol(mx) {
                                playerService.set_volume(Math.max(0, Math.min(100, (mx / width) * 100)))
                            }

                            onPressed: (m) => setVol(m.x)
                            onPositionChanged: (m) => { if (pressed) setVol(m.x) }
                        }
                    }

                    Text {
                        text: Math.round(playerService.volume) + "%"
                        color: theme.text_muted
                        font.pixelSize: 12
                        Layout.preferredWidth: 36
                    }
                }

                // Progress control
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: formatTime(playerService.position || 0)
                        color: theme.text_muted
                        font.pixelSize: 12
                        Layout.preferredWidth: 36
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24

                        property real dur: playerService.duration || 1
                        property real prog: dur > 0 ? (playerService.position || 0) / dur : 0

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: theme.border

                            Rectangle {
                                width: parent.parent.prog * parent.width
                                height: parent.height
                                radius: 2
                                color: pProgMouse.containsMouse ? theme.accent_hover : theme.accent
                            }

                            Rectangle {
                                x: Math.min(parent.parent.prog * parent.width - width / 2, parent.width - width / 2)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12
                                height: 12
                                radius: 6
                                color: theme.text_primary
                                visible: pProgMouse.containsMouse || pProgMouse.pressed
                            }
                        }

                        MouseArea {
                            id: pProgMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function seek(mx) {
                                playerService.seek((mx / width) * (playerService.duration || 1))
                            }

                            onPressed: (m) => seek(m.x)
                            onPositionChanged: (m) => { if (pressed) seek(m.x) }
                        }
                    }

                    Text {
                        text: formatTime(playerService.duration || 0)
                        color: theme.text_muted
                        font.pixelSize: 12
                        Layout.preferredWidth: 36
                    }
                }

                Item { Layout.preferredHeight: 12 }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 24

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 44
                        height: 44
                        radius: 22
                        color: prevPMouse.containsMouse ? theme.bg_hover : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        PlayIcon {
                            anchors.centerIn: parent
                            iconType: "skip_prev"
                            iconSize: 18
                            iconColor: prevPMouse.containsMouse ? theme.text_primary : theme.text_secondary
                        }

                        MouseArea {
                            id: prevPMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ctrl.previous()
                        }
                    }

                    Rectangle {
                        width: 64
                        height: 64
                        radius: 32
                        color: playPMouse.containsMouse ? "#E0E0E0" : theme.text_primary

                        scale: playPMouse.pressed ? 0.93 : (playPMouse.containsMouse ? 1.08 : 1.0)

                        Behavior on scale {
                            NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                        }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 10
                            source: ctrl.isPlaying ? "../assets/pause.svg" : "../assets/play.svg"
                            fillMode: Image.PreserveAspectFit
                            visible: theme.current_theme === "lukypurr"
                        }

                        PlayIcon {
                            anchors.centerIn: parent
                            iconType: ctrl.isPlaying ? "pause" : "play"
                            iconSize: 24
                            iconColor: theme.bg_main
                            visible: theme.current_theme !== "lukypurr"
                        }

                        MouseArea {
                            id: playPMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ctrl.toggle_play()
                        }
                    }

                    Rectangle {
                        width: 44
                        height: 44
                        radius: 22
                        color: nextPMouse.containsMouse ? theme.bg_hover : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        PlayIcon {
                            anchors.centerIn: parent
                            iconType: "skip_next"
                            iconSize: 18
                            iconColor: nextPMouse.containsMouse ? theme.text_primary : theme.text_secondary
                        }

                        MouseArea {
                            id: nextPMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ctrl.next()
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Item { Layout.preferredHeight: 20 }
            }

            Item { Layout.fillWidth: true }
        }

        Item { Layout.fillHeight: true; Layout.maximumHeight: 30 }
    }
}
