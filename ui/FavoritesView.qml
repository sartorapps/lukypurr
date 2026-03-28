import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    property var selectedIds: ({})

    function toggleSelect(videoId) {
        if (selectedIds[videoId]) {
            delete selectedIds[videoId]
        } else {
            selectedIds[videoId] = true
        }
        selectedIdsChanged()
    }

    function selectAll() {
        var favs = favoritesService.get_all()
        var allSelected = true
        for (var i = 0; i < favs.length; i++) {
            if (!selectedIds[favs[i].videoId]) {
                allSelected = false
                break
            }
        }
        var newSelected = {}
        if (!allSelected) {
            for (var j = 0; j < favs.length; j++) {
                newSelected[favs[j].videoId] = true
            }
        }
        selectedIds = newSelected
    }

    function addToQueue() {
        var favs = favoritesService.get_all()
        var wasEmpty = ctrl.queue.length === 0
        var startIdx = ctrl.queue.length
        var selected = []
        for (var i = 0; i < favs.length; i++) {
            if (selectedIds[favs[i].videoId]) {
                selected.push(favs[i])
            }
        }
        if (selected.length > 0) {
            ctrl.add_tracks_to_queue(selected)
            if (wasEmpty) {
                ctrl.play_from_queue(startIdx)
            }
        }
        selectedIds = {}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Favorites"
                color: theme.text_primary
                font.pixelSize: 24
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            // Select all
            Rectangle {
                height: 32
                width: selectAllText.implicitWidth + 24
                radius: 16
                color: selectAllMouse.containsMouse ? theme.bg_hover : theme.button_bg

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Text {
                    id: selectAllText
                    anchors.centerIn: parent
                    text: {
                        var favs = favoritesService.get_all()
                        var allSelected = favs.length > 0
                        for (var i = 0; i < favs.length; i++) {
                            if (!selectedIds[favs[i].videoId]) {
                                allSelected = false
                                break
                            }
                        }
                        allSelected ? "Deselect All" : "Select All"
                    }
                    color: theme.text_primary
                    font.pixelSize: 12
                }

                MouseArea {
                    id: selectAllMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: selectAll()
                }
            }

            // Add to queue
            Rectangle {
                height: 32
                width: addQueueText.implicitWidth + 24
                radius: 16
                color: {
                    var count = 0
                    for (var k in selectedIds) count++
                    return count > 0 ? theme.accent : theme.button_bg
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Text {
                    id: addQueueText
                    anchors.centerIn: parent
                    text: {
                        var count = 0
                        for (var k in selectedIds) count++
                        return count > 0 ? "Add " + count + " to Queue" : "Add to Queue"
                    }
                    color: {
                        var count = 0
                        for (var k in selectedIds) count++
                        return count > 0 ? theme.badge_text : theme.text_secondary
                    }
                    font.pixelSize: 12
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: addToQueue()
                }
            }
        }

        ListView {
            id: favList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: []
            clip: true
            spacing: 2

            Component.onCompleted: {
                model = favoritesService.get_all()
            }

            Connections {
                target: favoritesService
                function onFavoritesChanged() {
                    favList.model = favoritesService.get_all()
                }
            }

            delegate: Rectangle {
                width: ListView.view.width
                height: 56
                radius: 4
                property bool isSelected: selectedIds[modelData.videoId] || false
                property bool isCurrent: ctrl.currentTrack.videoId === modelData.videoId
                color: isCurrent ? theme.bg_hover : (favMouse.containsMouse ? theme.bg_card : "transparent")

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    // Checkbox
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 4
                        color: isSelected ? theme.accent : "transparent"
                        border.color: isSelected ? theme.accent : theme.border
                        border.width: 2

                        Text {
                            anchors.centerIn: parent
                            text: "\u2713"
                            color: theme.badge_text
                            font.pixelSize: 12
                            font.bold: true
                            visible: isSelected
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toggleSelect(modelData.videoId)
                            z: 10
                        }
                    }

                    Text {
                        text: (model.index + 1).toString()
                        color: isCurrent ? theme.accent : theme.text_muted
                        font.pixelSize: 13
                        Layout.preferredWidth: 24
                        horizontalAlignment: Text.AlignHCenter
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
                        color: theme.text_muted
                        font.pixelSize: 12
                    }

                    // Remove
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: removeFavMouse.containsMouse ? "#FF444433" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\u2715"
                            color: removeFavMouse.containsMouse ? "#FF4444" : "#FF6666"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: removeFavMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                ctrl.remove_favorite(modelData.videoId)
                                delete selectedIds[modelData.videoId]
                            }
                        }
                    }
                }

                MouseArea {
                    id: favMouse
                    anchors.fill: parent
                    anchors.leftMargin: 35
                    anchors.rightMargin: 40
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.play_favorite(model.index)
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: theme.border
                    opacity: 0.5
                }
            }
        }
    }
}
