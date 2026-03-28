import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
    id: trackRoot

    property var track: ({})
    property int index: 0
    property bool isCurrent: false
    property bool isFavorite: false
    property bool showRemove: false
    signal play()
    signal toggleFavorite()
    signal removeFavorite()

    property bool localFav: isFavorite
    onIsFavoriteChanged: localFav = isFavorite

    height: 56
    radius: 4
    color: isCurrent ? theme.bg_hover : (mouseArea.containsMouse ? theme.bg_card : "transparent")

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 12

        Text {
            text: (index + 1).toString()
            color: isCurrent ? theme.accent : theme.text_muted
            font.pixelSize: 13
            Layout.preferredWidth: 24
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            id: thumbContainer
            width: 40
            height: 40
            radius: 4
            color: theme.button_bg

            Image {
                id: thumbImg
                anchors.fill: parent
                source: track.thumbnail || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false

                Text {
                    anchors.centerIn: parent
                    text: "\u{1F3B5}"
                    font.pixelSize: 18
                    visible: thumbImg.status !== Image.Ready
                }
            }

            Rectangle {
                id: thumbMask
                anchors.fill: parent
                radius: 4
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: thumbImg
                maskSource: thumbMask
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: track.title || "Unknown"
                color: isCurrent ? theme.accent : theme.text_primary
                font.pixelSize: 14
                font.bold: isCurrent
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: track.artist || ""
                color: theme.text_secondary
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Text {
            text: track.duration || ""
            color: theme.text_muted
            font.pixelSize: 12
        }

        Rectangle {
            width: 30
            height: 30
            radius: 15
            color: removeMouse.containsMouse ? "#FF444433" : "transparent"
            visible: showRemove

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            Text {
                anchors.centerIn: parent
                text: "\u{2715}"
                color: removeMouse.containsMouse ? "#FF4444" : "#FF6666"
                font.pixelSize: 14
            }

            MouseArea {
                id: removeMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: removeFavorite()
            }
        }

        Rectangle {
            width: 30
            height: 30
            radius: 15
            color: heartMouse.containsMouse ? (localFav ? theme.accent + "33" : theme.text_primary + "15") : "transparent"
            visible: !showRemove

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            Text {
                id: heartIcon
                anchors.centerIn: parent
                text: localFav ? "\u{2665}" : "\u{2661}"
                color: localFav ? theme.accent : theme.text_muted
                font.pixelSize: 16

                scale: heartMouse.containsMouse ? 1.2 : 1.0

                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            MouseArea {
                id: heartMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    localFav = !localFav
                    toggleFavorite()
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: theme.border
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.rightMargin: 60
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: play()
        z: -1
    }
}
