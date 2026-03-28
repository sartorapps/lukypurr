import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Item {
    function copyToClipboard(text) {
        clipboardHelper.text = text
        clipboardHelper.selectAll()
        clipboardHelper.copy()
    }

    TextInput {
        id: clipboardHelper
        visible: false
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 32
        contentHeight: contentColumn.height
        clip: true
        flickableDirection: Flickable.VerticalFlick

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: 20

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Text {
                    text: "\u2665"
                    color: "#FF6B8A"
                    font.pixelSize: 28
                }

                Text {
                    text: "Support LukyPurr"
                    color: theme.text_primary
                    font.pixelSize: 24
                    font.bold: true
                }

                Item { Layout.fillWidth: true }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.bg_input
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 32

                // Luky the cat
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 200
                        Layout.preferredHeight: 200

                        Image {
                            id: lukyPhoto
                            anchors.fill: parent
                            source: "../donation/luky.png"
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }

                        Rectangle {
                            id: circleMask
                            anchors.fill: parent
                            radius: 100
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: lukyPhoto
                            maskSource: circleMask
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 100
                            color: "transparent"
                            border.color: theme.border
                            border.width: 2
                        }
                    }

                    Text {
                        text: "This is Luky \u2764"
                        color: theme.text_primary
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }

                // Description and wallets
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 16

                    Text {
                        text: "Every bit helps keep Luky happy!"
                        color: theme.text_primary
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: "Luky is a sweet and cuddly cat who loves treats, belly rubs, and napping in sunny spots. LukyPurr is built with love, and your donation helps buy Luky his favorite snacks and toys. Even a small contribution puts a smile on his little face!"
                        color: theme.text_secondary
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        lineHeight: 1.6
                    }

                    Text {
                        text: "This project is free and open-source. If you enjoy using LukyPurr, consider buying Luky a treat. He'll purr for you!"
                        color: theme.text_muted
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        lineHeight: 1.6
                    }

                    Item { Layout.preferredHeight: 4 }

                    Text {
                        text: "Donate with Crypto"
                        color: theme.accent
                        font.pixelSize: 16
                        font.bold: true
                    }

                    // BTC
                    CryptoRow {
                        Layout.fillWidth: true
                        coinName: "Bitcoin (BTC)"
                        walletAddress: "bc1q5227snghgvgpm2t4v6x20xumdkdq7he4wn0ruf"
                        qrSource: "../donation/qr-btc.png"
                    }

                    // ETH
                    CryptoRow {
                        Layout.fillWidth: true
                        coinName: "Ethereum (ETH)"
                        walletAddress: "0xb7F95e019a7b58D8bcA58e46Aa4183a80863F076"
                        qrSource: "../donation/qr-eth.png"
                    }

                    // SOL
                    CryptoRow {
                        Layout.fillWidth: true
                        coinName: "Solana (SOL)"
                        walletAddress: "8FGv2A9HQzvTna1AA3qYVnySfz4ZVtugnScorE9WwjvY"
                        qrSource: "../donation/qr-sol.png"
                    }

                    Item { Layout.preferredHeight: 8 }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }

    component CryptoRow: RowLayout {
        property string coinName: ""
        property string walletAddress: ""
        property string qrSource: ""
        property bool expanded: false

        spacing: 16

        // QR Code - clickable to expand
        Rectangle {
            id: qrContainer
            Layout.preferredWidth: expanded ? 220 : 100
            Layout.preferredHeight: expanded ? 220 : 100
            radius: 8
            color: expanded ? "#1A1A1A" : "#FFFFFF"
            clip: true

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Image {
                anchors.fill: parent
                anchors.margins: expanded ? 12 : 4
                source: qrSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: expanded = !expanded
            }
        }

        ColumnLayout {
            spacing: 6

            Text {
                text: coinName
                color: theme.text_primary
                font.pixelSize: 14
                font.bold: true
            }

            RowLayout {
                spacing: 8

                Text {
                    text: walletAddress
                    color: "#777777"
                    font.pixelSize: 11
                    font.family: "monospace"
                    Layout.maximumWidth: 300
                    elide: Text.ElideMiddle
                }

                // Copy button
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: copyMouse.containsMouse ? "#333333" : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: copyFeedback.visible ? "\u2713" : "\u2398"
                        color: copyFeedback.visible ? "#1DB954" : (copyMouse.containsMouse ? "#FFFFFF" : "#666666")
                        font.pixelSize: 14

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            copyToClipboard(walletAddress)
                            copyFeedback.visible = true
                            copyTimer.restart()
                        }
                    }

                    Timer {
                        id: copyTimer
                        interval: 1500
                        onTriggered: copyFeedback.visible = false
                    }

                    Item { id: copyFeedback; visible: false }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
