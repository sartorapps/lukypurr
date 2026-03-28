import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 1100
    height: 700
    minimumWidth: 900
    minimumHeight: 550
    visible: true
    title: "LukyPurr"
    color: theme.bg_main

    onClosing: function(close) {
        close.accepted = false
        root.hide()
    }

    Connections {
        target: trayService
        function onShowWindow() {
            root.show()
            root.raise()
            root.requestActivate()
        }
    }

    property string currentView: ctrl.currentView

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: theme.bg_sidebar

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                RowLayout {
                    spacing: 6
                    Layout.bottomMargin: 20

                    Text {
                        text: "\u{1F43E}"
                        color: theme.text_primary
                        font.pixelSize: 20
                    }

                    Text {
                        text: "LukyPurr"
                        color: theme.text_primary
                        font.pixelSize: 22
                        font.bold: true
                    }
                }

                NavButton {
                    icon: "\u{1F50D}"
                    label: "Search"
                    active: currentView === "search"
                    onClicked: ctrl.set_view("search")
                }

                NavButton {
                    icon: "\u{25B6}"
                    label: "Playing"
                    active: currentView === "playing"
                    onClicked: ctrl.set_view("playing")
                }

                NavButton {
                    icon: "\u{2665}"
                    label: "Favorites"
                    active: currentView === "favorites"
                    onClicked: ctrl.set_view("favorites")
                }

                NavButton {
                    icon: "\u{23F8}"
                    label: "Queue"
                    active: currentView === "queue"
                    badge: ctrl.queue.length > 0 ? ctrl.queue.length.toString() : ""
                    onClicked: ctrl.set_view("queue")
                }

                Item { Layout.fillHeight: true }

                NavButton {
                    icon: "\u2699"
                    label: "Settings"
                    active: currentView === "settings"
                    onClicked: ctrl.set_view("settings")
                }

                NavButton {
                    icon: "\u2615"
                    label: "Support"
                    active: currentView === "donation"
                    onClicked: ctrl.set_view("donation")
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: theme.border
                }

                Text {
                    text: "Now Playing"
                    color: theme.text_muted
                    font.pixelSize: 11
                    Layout.topMargin: 8
                }

                Text {
                    text: ctrl.currentTrack.title || "Nothing"
                    color: theme.text_primary
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    maximumLineCount: 1
                }

                Text {
                    text: ctrl.currentTrack.artist || ""
                    color: theme.text_secondary
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: theme.bg_surface

                SearchView {
                    anchors.fill: parent
                    visible: currentView === "search"
                }

                PlayingView {
                    anchors.fill: parent
                    visible: currentView === "playing"
                }

                FavoritesView {
                    anchors.fill: parent
                    visible: currentView === "favorites"
                }

                QueueView {
                    anchors.fill: parent
                    visible: currentView === "queue"
                }

                DonationView {
                    anchors.fill: parent
                    visible: currentView === "donation"
                }

                SettingsView {
                    anchors.fill: parent
                    visible: currentView === "settings"
                }
            }

            PlayerBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
            }
        }
    }

    component NavButton: Rectangle {
        property string icon: ""
        property string label: ""
        property bool active: false
        property string badge: ""
        signal clicked()

        Layout.fillWidth: true
        height: 40
        radius: 6
        color: active ? theme.bg_hover : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Text {
                text: icon
                font.pixelSize: 18
                color: active ? theme.icon_accent_active : theme.icon_accent
            }

            Text {
                text: label
                font.pixelSize: 14
                font.bold: active
                color: active ? theme.text_primary : theme.text_secondary
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: badgeText.implicitWidth + 10
                height: 20
                radius: 10
                color: active ? theme.badge_bg : theme.button_bg
                visible: badge !== ""

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: badge
                    color: active ? theme.badge_text : theme.text_secondary
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
