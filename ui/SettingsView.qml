import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    Flickable {
        anchors.fill: parent
        anchors.margins: 32
        contentHeight: settingsColumn.height
        clip: true
        flickableDirection: Flickable.VerticalFlick

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: settingsColumn
            width: parent.width
            spacing: 28

            RowLayout {
                spacing: 12

                Text {
                    text: "\u2699"
                    color: theme.text_primary
                    font.pixelSize: 24
                }

                Text {
                    text: "Settings"
                    color: theme.text_primary
                    font.pixelSize: 24
                    font.bold: true
                }

                Item { Layout.fillWidth: true }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.border
            }

            // Theme selector
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Theme"
                    color: theme.text_primary
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    text: "Choose your preferred color scheme"
                    color: theme.text_muted
                    font.pixelSize: 13
                }

                ComboBox {
                    id: themeCombo
                    Layout.fillWidth: true
                    model: theme.available_themes
                    currentIndex: {
                        for (var i = 0; i < model.length; i++) {
                            if (model[i].id === theme.current_theme) return i
                        }
                        return 0
                    }
                    onActivated: (idx) => theme.set_theme(model[idx].id)

                    background: Rectangle {
                        radius: 6
                        color: theme.bg_input
                        border.color: theme.border
                        border.width: 1
                    }

                    popup: Popup {
                        y: themeCombo.height
                        width: themeCombo.width
                        implicitHeight: contentItem.implicitHeight + 2
                        padding: 1

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: themeCombo.popup.visible ? themeCombo.delegateModel : null
                            currentIndex: themeCombo.highlightedIndex
                            ScrollBar.vertical: ScrollBar {}
                        }

                        background: Rectangle {
                            radius: 6
                            color: theme.bg_surface
                            border.color: theme.border
                            border.width: 1
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 8

                        RowLayout {
                            spacing: 3
                            Layout.preferredWidth: 50

                            Rectangle {
                                Layout.fillWidth: true
                                height: 12
                                radius: 2
                                color: theme.available_themes[themeCombo.currentIndex].bg
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 12
                                radius: 2
                                color: theme.available_themes[themeCombo.currentIndex].accent
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 12
                                radius: 2
                                color: theme.available_themes[themeCombo.currentIndex].text
                            }
                        }

                        Text {
                            text: theme.available_themes[themeCombo.currentIndex].name
                            color: theme.text_primary
                            font.pixelSize: 14
                            Layout.fillWidth: true
                        }
                    }

                    delegate: ItemDelegate {
                        width: themeCombo.width
                        height: 40

                        contentItem: RowLayout {
                            spacing: 8

                            RowLayout {
                                spacing: 3
                                Layout.preferredWidth: 50

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 10
                                    radius: 2
                                    color: modelData.bg
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 10
                                    radius: 2
                                    color: modelData.accent
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 10
                                    radius: 2
                                    color: modelData.text
                                }
                            }

                            Text {
                                text: modelData.name
                                color: themeCombo.currentIndex === index ? theme.accent : theme.text_primary
                                font.pixelSize: 13
                                font.bold: themeCombo.currentIndex === index
                                Layout.fillWidth: true
                            }
                        }

                        background: Rectangle {
                            color: highlighted ? theme.bg_hover : "transparent"
                        }
                    }
                }
            }

            // Spectrum color
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Spectrum Gradient Color"
                    color: theme.text_primary
                    font.pixelSize: 16
                    font.bold: true
                }

                RowLayout {
                    spacing: 12

                    Repeater {
                        model: ["#1DB954", "#4A90D9", "#E74C3C", "#F39C12", "#9B59B6", "#1ABC9C", "#E91E63", "#FFFFFF"]

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: modelData
                            border.color: settingsService.gradient_color === modelData ? theme.text_primary : "transparent"
                            border.width: settingsService.gradient_color === modelData ? 3 : 0

                            scale: colorMouse.containsMouse ? 1.15 : 1.0

                            Behavior on scale {
                                NumberAnimation { duration: 100; easing.type: Easing.OutBack }
                            }

                            MouseArea {
                                id: colorMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsService.set_gradient_color(modelData)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            // Intensity with +/- buttons
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Color Intensity"
                    color: theme.text_primary
                    font.pixelSize: 16
                    font.bold: true
                }

                RowLayout {
                    spacing: 10

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: minusIntMouse.containsMouse ? theme.bg_hover : theme.button_bg

                        Text {
                            anchors.centerIn: parent
                            text: "\u2212"
                            color: theme.text_primary
                            font.pixelSize: 18
                            font.bold: true
                        }

                        MouseArea {
                            id: minusIntMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsService.set_gradient_intensity(Math.max(0, settingsService.gradient_intensity - 5))
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            radius: 3
                            color: theme.border

                            Rectangle {
                                width: (settingsService.gradient_intensity / 100) * parent.width
                                height: parent.height
                                radius: 3
                                color: settingsService.gradient_color
                            }

                            Rectangle {
                                x: Math.min((settingsService.gradient_intensity / 100) * parent.width - width/2, parent.width - width/2)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                radius: 8
                                color: theme.text_primary
                                visible: intensityMouse.containsMouse || intensityMouse.pressed
                            }

                            MouseArea {
                                id: intensityMouse
                                anchors.fill: parent
                                anchors.topMargin: -10
                                anchors.bottomMargin: -10
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                function setIntensity(mx) {
                                    settingsService.set_gradient_intensity(Math.max(0, Math.min(100, (mx / width) * 100)))
                                }

                                onPressed: (m) => setIntensity(m.x)
                                onPositionChanged: (m) => { if (pressed) setIntensity(m.x) }
                            }
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: plusIntMouse.containsMouse ? theme.bg_hover : theme.button_bg

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: theme.text_primary
                            font.pixelSize: 18
                            font.bold: true
                        }

                        MouseArea {
                            id: plusIntMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsService.set_gradient_intensity(Math.min(100, settingsService.gradient_intensity + 5))
                        }
                    }

                    Text {
                        text: Math.round(settingsService.gradient_intensity) + "%"
                        color: theme.text_muted
                        font.pixelSize: 13
                        Layout.preferredWidth: 40
                    }
                }
            }

            // Opacity with +/- buttons
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Spectrum Opacity"
                    color: theme.text_primary
                    font.pixelSize: 16
                    font.bold: true
                }

                RowLayout {
                    spacing: 10

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: minusOpMouse.containsMouse ? theme.bg_hover : theme.button_bg

                        Text {
                            anchors.centerIn: parent
                            text: "\u2212"
                            color: theme.text_primary
                            font.pixelSize: 18
                            font.bold: true
                        }

                        MouseArea {
                            id: minusOpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsService.set_gradient_opacity(Math.max(5, settingsService.gradient_opacity - 5))
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            radius: 3
                            color: theme.border

                            Rectangle {
                                width: (settingsService.gradient_opacity / 100) * parent.width
                                height: parent.height
                                radius: 3
                                color: settingsService.gradient_color
                            }

                            Rectangle {
                                x: Math.min((settingsService.gradient_opacity / 100) * parent.width - width/2, parent.width - width/2)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                radius: 8
                                color: theme.text_primary
                                visible: opacityMouse.containsMouse || opacityMouse.pressed
                            }

                            MouseArea {
                                id: opacityMouse
                                anchors.fill: parent
                                anchors.topMargin: -10
                                anchors.bottomMargin: -10
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                function setOpacity(mx) {
                                    settingsService.set_gradient_opacity(Math.max(5, Math.min(100, (mx / width) * 100)))
                                }

                                onPressed: (m) => setOpacity(m.x)
                                onPositionChanged: (m) => { if (pressed) setOpacity(m.x) }
                            }
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: plusOpMouse.containsMouse ? theme.bg_hover : theme.button_bg

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: theme.text_primary
                            font.pixelSize: 18
                            font.bold: true
                        }

                        MouseArea {
                            id: plusOpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsService.set_gradient_opacity(Math.min(100, settingsService.gradient_opacity + 5))
                        }
                    }

                    Text {
                        text: Math.round(settingsService.gradient_opacity) + "%"
                        color: theme.text_muted
                        font.pixelSize: 13
                        Layout.preferredWidth: 40
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
