import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    color: theme.player_bg
    border.color: theme.border
    border.width: 1

    property bool localFav: ctrl.currentTrack.videoId ? favoritesService.is_favorite(ctrl.currentTrack.videoId) : false

    Connections {
        target: favoritesService
        function onFavoritesChanged() {
            localFav = ctrl.currentTrack.videoId ? favoritesService.is_favorite(ctrl.currentTrack.videoId) : false
        }
    }

    Connections {
        target: ctrl
        function onCurrentTrackChanged() {
            localFav = ctrl.currentTrack.videoId ? favoritesService.is_favorite(ctrl.currentTrack.videoId) : false
        }
    }

    function formatTime(seconds) {
        var s = Math.floor(seconds)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        // Progress bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: formatTime(playerService.position || 0)
                        color: theme.text_muted
                font.pixelSize: 11
                Layout.preferredWidth: 40
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 20

                property real duration: playerService.duration || 1
                property real progress: duration > 0 ? (playerService.position || 0) / duration : 0

                // Background track
                Rectangle {
                    id: progressTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: theme.border

                    // Filled portion
                    Rectangle {
                        width: parent.parent.progress * parent.width
                        height: parent.height
                        radius: 2
                        color: progressBarMouse.containsMouse ? theme.accent_hover : theme.accent

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    // Handle
                    Rectangle {
                        x: Math.min(parent.parent.progress * parent.width - width / 2, parent.width - width / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        radius: 6
                        color: theme.text_primary
                        visible: progressBarMouse.containsMouse || progressBarMouse.pressed
                    }
                }

                MouseArea {
                    id: progressBarMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function seekTo(mouseX) {
                        var ratio = mouseX / width
                        ratio = Math.max(0, Math.min(1, ratio))
                        playerService.seek(ratio * (playerService.duration || 1))
                    }

                    onPressed: (mouse) => seekTo(mouse.x)
                    onPositionChanged: (mouse) => {
                        if (pressed) seekTo(mouse.x)
                    }
                }
            }

            Text {
                text: formatTime(playerService.duration || 0)
                        color: theme.text_muted
                font.pixelSize: 11
                Layout.preferredWidth: 40
            }
        }

        // Controls row
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Previous
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: prevMouse.containsMouse ? theme.bg_hover : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                PlayIcon {
                    anchors.centerIn: parent
                    iconType: "skip_prev"
                    iconSize: 14
                    iconColor: prevMouse.containsMouse ? theme.text_primary : theme.text_secondary
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.previous()
                }
            }

            // Play/Pause
            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: playMouse.containsMouse ? "#E0E0E0" : theme.text_primary

                scale: playMouse.containsMouse ? 1.1 : 1.0

                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 6
                    source: ctrl.isPlaying ? "../assets/pause.svg" : "../assets/play.svg"
                    fillMode: Image.PreserveAspectFit
                    visible: theme.current_theme === "lukypurr"
                }

                PlayIcon {
                    anchors.centerIn: parent
                    iconType: ctrl.isPlaying ? "pause" : "play"
                    iconSize: 16
                    iconColor: theme.bg_main
                    visible: theme.current_theme !== "lukypurr"
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.toggle_play()
                }
            }

            // Next
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: nextMouse.containsMouse ? theme.bg_hover : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                PlayIcon {
                    anchors.centerIn: parent
                    iconType: "skip_next"
                    iconSize: 14
                    iconColor: nextMouse.containsMouse ? theme.text_primary : theme.text_secondary
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.next()
                }
            }

            Item { Layout.preferredWidth: 12 }

            // Track info
            Text {
                text: ctrl.currentTrack.title || "No track"
                color: theme.text_primary
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: ctrl.currentTrack.artist || ""
                        color: theme.text_muted
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.preferredWidth: 150
            }

            Item { Layout.preferredWidth: 8 }

            // Volume control
            RowLayout {
                spacing: 6

                Text {
                    text: playerService.volume > 50 ? "\u{1F50A}" : (playerService.volume > 0 ? "\u{1F509}" : "\u{1F507}")
                    color: "#666666"
                    font.pixelSize: 14
                }

                Item {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 20

                    Rectangle {
                        id: volumeTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: theme.border

                        Rectangle {
                            width: (playerService.volume / 100) * parent.width
                            height: parent.height
                            radius: 2
                            color: volumeBarMouse.containsMouse ? theme.accent_hover : theme.accent
                        }

                        Rectangle {
                            x: Math.min((playerService.volume / 100) * parent.width - width / 2, parent.width - width / 2)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            radius: 5
                            color: theme.text_primary
                            visible: volumeBarMouse.containsMouse || volumeBarMouse.pressed
                        }
                    }

                    MouseArea {
                        id: volumeBarMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function setVolume(mouseX) {
                            var vol = (mouseX / width) * 100
                            vol = Math.max(0, Math.min(100, vol))
                            playerService.set_volume(vol)
                        }

                        onPressed: (mouse) => setVolume(mouse.x)
                        onPositionChanged: (mouse) => {
                            if (pressed) setVolume(mouse.x)
                        }
                    }
                }

                Text {
                    text: Math.round(playerService.volume) + "%"
                        color: theme.text_muted
                    font.pixelSize: 11
                    Layout.preferredWidth: 32
                }
            }

            Item { Layout.preferredWidth: 8 }

            // Favorite
            Rectangle {
                width: 30
                height: 30
                radius: 15
                color: favBarMouse.containsMouse ? (localFav ? theme.accent + "33" : theme.text_primary + "15") : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Text {
                    anchors.centerIn: parent
                    text: localFav ? "\u{2665}" : "\u{2661}"
                    color: localFav ? theme.accent : theme.text_muted
                    font.pixelSize: 18

                    scale: favBarMouse.containsMouse ? 1.3 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                    }
                }

                MouseArea {
                    id: favBarMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        localFav = !localFav
                        if (ctrl.currentTrack.videoId) {
                            ctrl.toggle_favorite(ctrl.currentTrack)
                        }
                    }
                }
            }
        }
    }
}
