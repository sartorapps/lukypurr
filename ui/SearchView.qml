import QtQuick
import QtQuick.Layouts

Item {
    property int favVersion: 0

    Connections {
        target: favoritesService
        function onFavoritesChanged() {
            favVersion++
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 22
                color: theme.bg_input

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.text_primary
                    font.pixelSize: 14
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search for songs, artists..."
                        color: theme.text_muted
                        visible: searchInput.text.length === 0 && !searchInput.activeFocus
                    }

                    onAccepted: ctrl.search(text)
                }
            }

            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: searchBtnMouse.containsMouse ? theme.text_secondary : theme.text_primary

                scale: searchBtnMouse.containsMouse ? 1.08 : 1.0

                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                PlayIcon {
                    anchors.centerIn: parent
                    iconType: "search"
                    iconSize: 18
                    iconColor: "#000000"
                }

                MouseArea {
                    id: searchBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.search(searchInput.text)
                }
            }
        }

        Text {
            text: ctrl.searchResults.length > 0 ? "Results" : "Search for music"
            color: theme.text_secondary
            font.pixelSize: 13
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: ctrl.searchResults
            clip: true
            spacing: 2

            delegate: TrackItem {
                width: ListView.view.width
                track: modelData
                index: model.index
                isCurrent: ctrl.currentTrack.videoId === modelData.videoId
                isFavorite: favoritesService.is_favorite(modelData.videoId) ? (favVersion, true) : (favVersion, false)
                onPlay: ctrl.play_track(index)
                onToggleFavorite: ctrl.toggle_favorite(modelData)
            }
        }
    }
}
