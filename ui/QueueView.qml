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
                text: "Queue"
                color: theme.text_primary
                font.pixelSize: 24
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Text {
                text: ctrl.queue.length + " tracks"
                color: theme.text_muted
                font.pixelSize: 13
            }

            Rectangle {
                width: 80
                height: 30
                radius: 15
                color: clearMouse.containsMouse ? "#FF444444" : "#333333"

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Clear"
                    color: clearMouse.containsMouse ? "#FF4444" : "#AAAAAA"
                    font.pixelSize: 12
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.clear_queue()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.border
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: ctrl.queue
            clip: true
            spacing: 2

            delegate: Rectangle {
                width: ListView.view.width
                height: 56
                radius: 4
                property bool isCurrent: model.index === ctrl.queueIndex
                property bool isHovered: queueMouse.containsMouse
                color: isCurrent ? "#282828" : (isHovered ? "#1E1E1E" : "transparent")

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

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
                        id: qThumbBg
                        width: 40
                        height: 40
                        radius: 4
                        color: theme.border

                        Image {
                            id: qThumbImg
                            anchors.fill: parent
                            source: modelData.thumbnail || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false

                            Text {
                                anchors.centerIn: parent
                                text: "\u{1F3B5}"
                                font.pixelSize: 16
                                visible: qThumbImg.status !== Image.Ready
                            }
                        }

                        Rectangle {
                            id: qThumbMask
                            anchors.fill: parent
                            radius: 4
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: qThumbImg
                            maskSource: qThumbMask
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
                            text: modelData.artist || ""
                            color: theme.text_secondary
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: modelData.duration || ""
                        color: "#555555"
                        font.pixelSize: 12
                    }

                    Text {
                        text: model.index === ctrl.queueIndex ? "\u{25B6}" : ""
                        color: theme.accent
                        font.pixelSize: 12
                        Layout.preferredWidth: 20
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: "transparent"
                        visible: model.index !== ctrl.queueIndex

                        Text {
                            anchors.centerIn: parent
                            text: "\u{2715}"
                            color: removeQMouse.containsMouse ? "#FF4444" : "#555555"
                            font.pixelSize: 11

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        MouseArea {
                            id: removeQMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: ctrl.remove_from_queue(model.index)
                        }
                    }
                }

                MouseArea {
                    id: queueMouse
                    anchors.fill: parent
                    anchors.rightMargin: 40
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.play_from_queue(model.index)
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
