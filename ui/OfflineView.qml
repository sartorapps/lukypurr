import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Offline"
                color: theme.text_primary
                font.pixelSize: 24
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Text {
                text: ctrl.offline_tracks.length + " files"
                color: theme.text_muted
                font.pixelSize: 13
            }

            // Botao Shuffle: embaralha a lista offline e toca do inicio
            Rectangle {
                height: 30
                width: shuffleText.implicitWidth + 24
                radius: 15
                color: ctrl.offlineShuffle ? theme.accent : (shuffleMouse.containsMouse ? theme.bg_hover : theme.button_bg)

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: shuffleText
                    anchors.centerIn: parent
                    text: "\u{1F500} Shuffle"
                    color: ctrl.offlineShuffle ? "#000000" : theme.text_primary
                    font.pixelSize: 12
                    font.bold: ctrl.offlineShuffle
                }

                MouseArea {
                    id: shuffleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.shuffle_offline()
                }
            }

            // Botao Repeat: repete a lista offline ao terminar
            Rectangle {
                height: 30
                width: repeatText.implicitWidth + 24
                radius: 15
                color: ctrl.offlineRepeat ? theme.accent : (repeatMouse.containsMouse ? theme.bg_hover : theme.button_bg)

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: repeatText
                    anchors.centerIn: parent
                    text: "\u{1F501} Repeat"
                    color: ctrl.offlineRepeat ? "#000000" : theme.text_primary
                    font.pixelSize: 12
                    font.bold: ctrl.offlineRepeat
                }

                MouseArea {
                    id: repeatMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.toggle_offline_repeat()
                }
            }

            Rectangle {
                height: 30
                width: rescanText.implicitWidth + 24
                radius: 15
                color: rescanMouse.containsMouse ? theme.bg_hover : theme.button_bg

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: rescanText
                    anchors.centerIn: parent
                    text: "Rescan"
                    color: theme.text_primary
                    font.pixelSize: 12
                }

                MouseArea {
                    id: rescanMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.scan_offline()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.border
        }

        // Aviso: pasta de MP3 nao configurada
        Rectangle {
            Layout.fillWidth: true
            visible: ctrl.downloadFolder === ""
            radius: 8
            color: theme.bg_card
            border.color: theme.border
            border.width: 1
            height: 90

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Text {
                    text: "\u{1F4C2}"
                    font.pixelSize: 28
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "No MP3 folder configured"
                        color: theme.text_primary
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: "Download music from the player bar or choose the folder where your files are."
                        color: theme.text_muted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 120
                    height: 36
                    radius: 6
                    color: pickMouse.containsMouse ? theme.bg_hover : theme.button_bg

                    Text {
                        anchors.centerIn: parent
                        text: "Escolher pasta"
                        color: theme.text_primary
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        id: pickMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ctrl.pick_download_folder()
                    }
                }
            }
        }

        // Aviso: pasta vazia / sem audio
        Text {
            Layout.fillWidth: true
            visible: ctrl.downloadFolder !== "" && ctrl.offline_tracks.length === 0
            text: "No audio files found in:\n" + (ctrl.downloadFolder || "")
            color: theme.text_muted
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: ctrl.offline_tracks
            clip: true
            spacing: 2
            visible: ctrl.offline_tracks.length > 0

            delegate: Rectangle {
                width: ListView.view.width
                height: 56
                radius: 4
                property bool isCurrent: ctrl.currentTrack.path === modelData.path
                property bool isHovered: offMouse.containsMouse
                color: isCurrent ? "#282828" : (isHovered ? "#1E1E1E" : "transparent")

                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    visible: isCurrent && ctrl.isPlaying
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: parent.height * 0.6
                    radius: 1
                    color: theme.accent
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Text {
                        text: (model.index + 1).toString()
                        color: isCurrent ? theme.accent : theme.text_muted
                        font.pixelSize: 13
                        Layout.preferredWidth: 24
                        horizontalAlignment: Text.AlignHCenter
                        font.bold: isCurrent
                    }

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 4
                        color: theme.border

                        Image {
                            id: offThumbImg
                            anchors.fill: parent
                            source: modelData.thumbnail || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false

                            Text {
                                anchors.centerIn: parent
                                text: "\u{1F3B5}"
                                font.pixelSize: 16
                                visible: offThumbImg.status !== Image.Ready
                            }
                        }

                        Rectangle {
                            id: offThumbMask
                            anchors.fill: parent
                            radius: 4
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: offThumbImg
                            maskSource: offThumbMask
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: modelData.title || "Unknown"
                            color: isCurrent ? theme.accent : theme.text_primary
                            font.pixelSize: 14
                            font.bold: isCurrent
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: modelData.artist || "Unknown artist"
                            color: theme.text_secondary
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: isCurrent && ctrl.isPlaying ? "\u{25B6}" : ""
                        color: theme.accent
                        font.pixelSize: 12
                        Layout.preferredWidth: 20
                    }
                }

                MouseArea {
                    id: offMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.play_offline(model.index)
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: theme.bg_card
                }
            }
        }
    }
}
