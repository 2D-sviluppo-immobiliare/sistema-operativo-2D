import QtQuick

// Chat2D - interfaccia dell'assistente multi-provider.
//
// La shell parla con il server locale (backend/chat_server.py), che e' l'unico
// a conoscere le chiavi. Qui non c'e' nessun segreto: solo stato, messaggi e il
// pannello per scegliere provider, modello e chiave.
Item {
    id: chat

    property bool settingsOpen: false
    property var providerList: []
    property string selectedProvider: ""
    property string selectedModel: ""
    property string providerHint: ""

    function reloadProviders() {
        providerList = chatClient.providers()
    }

    function openSettings() {
        reloadProviders()
        selectedProvider = chatClient.activeProvider
        var info = chatClient.provider(selectedProvider)
        selectedModel = info.model || ""
        keyField.text = ""
        providerHint = info.hasKey ? "Chiave già salvata. Lascia vuoto per non cambiarla." : ""
        settingsOpen = true
    }

    function selectProvider(id) {
        selectedProvider = id
        var info = chatClient.provider(id)
        selectedModel = info.model || ""
        keyField.text = ""
        providerHint = info.hasKey
                ? "Chiave già salvata. Lascia vuoto per non cambiarla."
                : "Nessuna chiave salvata per " + info.label + "."
    }

    Component.onCompleted: {
        chatClient.start()
        reloadProviders()
    }

    Connections {
        target: chatClient
        function onConfigChanged() { chat.reloadProviders() }
        function onStatusChanged() { chat.reloadProviders() }
    }

    // --- barra di stato ------------------------------------------------------
    Rectangle {
        id: statusBar

        width: parent.width
        height: 38
        color: "#071724"

        Rectangle {
            id: statusDot

            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 3.5
            color: chatClient.status === "ready" ? "#4bc47a"
                 : chatClient.status === "connecting" ? "#f9b234"
                 : chatClient.status === "unconfigured" ? "#e0b455"
                 : "#7d93a6"

            SequentialAnimation on opacity {
                running: chatClient.status === "connecting" || chatClient.busy
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 600 }
                NumberAnimation { to: 1.0; duration: 600 }
            }
        }

        Text {
            id: statusLabel

            anchors.left: statusDot.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: chatClient.status === "ready" ? "CONNESSO"
                 : chatClient.status === "connecting" ? "CONNESSIONE"
                 : chatClient.status === "unconfigured" ? "DA CONFIGURARE"
                 : "OFFLINE"
            color: chatClient.status === "ready" ? "#8fe0ac" : Theme.textDim
            font.family: "DejaVu Sans"
            font.pixelSize: 8
            font.letterSpacing: 1.4
        }

        Text {
            anchors.left: statusLabel.right
            anchors.leftMargin: 10
            anchors.right: settingsButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: chatClient.status === "ready"
                  ? chatClient.activeLabel + " · " + chatClient.model
                  : chatClient.detail
            color: Theme.textFaint
            font.family: "DejaVu Sans"
            font.pixelSize: 8
        }

        Rectangle {
            id: settingsButton

            anchors.right: clearButton.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: 6
            color: settingsOpen ? "#1b3348"
                 : settingsMouse.containsMouse ? "#17304a" : "#0d1e2e"
            border.width: 1
            border.color: "#1fffffff"

            Text {
                anchors.centerIn: parent
                text: "\u2699"
                color: Theme.textDim
                font.family: "DejaVu Sans"
                font.pixelSize: 12
            }

            MouseArea {
                id: settingsMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: chat.settingsOpen ? chat.settingsOpen = false : chat.openSettings()
            }
        }

        Rectangle {
            id: clearButton

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            height: 24
            radius: 6
            color: clearMouse.containsMouse ? "#17304a" : "#0d1e2e"
            border.width: 1
            border.color: "#1fffffff"

            Text {
                anchors.centerIn: parent
                text: "Pulisci"
                color: Theme.textDim
                font.family: "DejaVu Sans"
                font.pixelSize: 8
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: chatClient.clear()
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#12ffffff"
        }
    }

    // --- pannello di configurazione -----------------------------------------
    Item {
        id: settingsPanel

        anchors.top: statusBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: chat.settingsOpen

        Flickable {
            anchors.fill: parent
            contentHeight: settingsColumn.implicitHeight + 28
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: settingsColumn

                x: 16
                y: 12
                width: parent.width - 32
                spacing: 7

                Text {
                    text: "PROVIDER"
                    color: Theme.textFaint
                    font.family: "DejaVu Sans"
                    font.pixelSize: 8
                    font.letterSpacing: 1.8
                }

                Repeater {
                    model: chat.providerList

                    Rectangle {
                        id: providerRow

                        required property var modelData

                        width: settingsColumn.width
                        height: 31
                        radius: 8
                        color: chat.selectedProvider === modelData.id
                               ? "#1b3348"
                               : providerMouse.containsMouse ? "#122536" : "#0a1826"
                        border.width: 1
                        border.color: chat.selectedProvider === modelData.id
                                      ? "#88f9b234"
                                      : "#1fffffff"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: providerRow.modelData.hasKey ? "#4bc47a" : "#7d93a6"
                            }

                            Text {
                                text: providerRow.modelData.label
                                color: chat.selectedProvider === providerRow.modelData.id
                                       ? Theme.text : Theme.textDim
                                font.family: "DejaVu Sans"
                                font.pixelSize: 10
                            }

                            Text {
                                text: providerRow.modelData.hasKey ? "chiave presente" : "chiave assente"
                                color: providerRow.modelData.hasKey ? "#5f8f70" : "#5f7285"
                                font.family: "DejaVu Sans"
                                font.pixelSize: 8
                            }
                        }

                        MouseArea {
                            id: providerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: chat.selectProvider(providerRow.modelData.id)
                        }
                    }
                }

                Text {
                    text: "MODELLO"
                    color: Theme.textFaint
                    font.family: "DejaVu Sans"
                    font.pixelSize: 8
                    font.letterSpacing: 1.8
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: 7
                    color: "#05121e"
                    border.width: 1
                    border.color: modelField.activeFocus ? "#88f9b234" : "#1fffffff"

                    TextInput {
                        id: modelField

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        selectionColor: "#556fbdbd"
                        selectedTextColor: "#031020"
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 10
                        text: chat.selectedModel
                        clip: true

                        onTextChanged: chat.selectedModel = text
                    }
                }

                Text {
                    text: "CHIAVE API"
                    color: Theme.textFaint
                    font.family: "DejaVu Sans"
                    font.pixelSize: 8
                    font.letterSpacing: 1.8
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: 7
                    color: "#05121e"
                    border.width: 1
                    border.color: keyField.activeFocus ? "#88f9b234" : "#1fffffff"

                    TextInput {
                        id: keyField

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        selectionColor: "#556fbdbd"
                        selectedTextColor: "#031020"
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 10
                        echoMode: TextInput.Password
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: keyField.text === ""
                            text: "incolla qui la chiave"
                            color: Theme.textFaint
                            font.family: "DejaVu Sans"
                            font.pixelSize: 9
                        }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: chat.providerHint
                    color: "#8fa9bd"
                    font.family: "DejaVu Sans"
                    font.pixelSize: 8
                    lineHeight: 1.3
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "La chiave viene salvata in ~/.config/2d-os/chat2d.json "
                        + "con permessi 0600 e non lascia mai questa macchina "
                        + "se non verso il provider scelto."
                    color: "#5f7285"
                    font.family: "DejaVu Sans"
                    font.pixelSize: 8
                    lineHeight: 1.25
                }

                Row {
                    spacing: 8

                    Rectangle {
                        width: 130
                        height: 30
                        radius: 8
                        color: saveMouse.containsMouse ? "#ffc85a" : "#f9b234"
                        border.width: 1
                        border.color: "#ffdf9e"

                        Text {
                            anchors.centerIn: parent
                            text: "Salva e attiva"
                            color: "#031020"
                            font.family: "DejaVu Sans"
                            font.pixelSize: 9
                            font.bold: true
                        }

                        MouseArea {
                            id: saveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (chatClient.saveProvider(chat.selectedProvider,
                                                            keyField.text,
                                                            chat.selectedModel)) {
                                    chat.providerHint = "Configurazione salvata."
                                    keyField.text = ""
                                    chat.reloadProviders()
                                } else {
                                    chat.providerHint = "Salvataggio non riuscito."
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 90
                        height: 30
                        radius: 8
                        color: closeMouse.containsMouse ? "#17304a" : "#0d1e2e"
                        border.width: 1
                        border.color: "#1fffffff"

                        Text {
                            anchors.centerIn: parent
                            text: "Chiudi"
                            color: Theme.textDim
                            font.family: "DejaVu Sans"
                            font.pixelSize: 9
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: chat.settingsOpen = false
                        }
                    }
                }
            }
        }
    }

    // --- avviso di configurazione -------------------------------------------
    Rectangle {
        id: setupBanner

        anchors.top: statusBar.bottom
        width: parent.width
        height: visible ? setupColumn.implicitHeight + 22 : 0
        visible: chatClient.status === "unconfigured" && !chat.settingsOpen
        color: "#1a1408"

        Column {
            id: setupColumn

            x: 16
            y: 11
            width: parent.width - 32
            spacing: 6

            Text {
                width: parent.width
                text: "Chat2D deve essere configurato"
                color: "#e0b455"
                font.family: "DejaVu Sans"
                font.pixelSize: 10
                font.bold: true
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: chatClient.detail
                color: "#b9c9d6"
                font.family: "DejaVu Sans"
                font.pixelSize: 9
                lineHeight: 1.3
            }

            Rectangle {
                width: 150
                height: 28
                radius: 7
                color: configMouse.containsMouse ? "#17304a" : "#0d1e2e"
                border.width: 1
                border.color: "#33e0b455"

                Text {
                    anchors.centerIn: parent
                    text: "Configura ora"
                    color: "#e0b455"
                    font.family: "DejaVu Sans"
                    font.pixelSize: 9
                }

                MouseArea {
                    id: configMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: chat.openSettings()
                }
            }
        }
    }

    // --- conversazione -------------------------------------------------------
    ListView {
        id: messageList

        anchors.top: setupBanner.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: composer.top
        anchors.margins: 14
        visible: !chat.settingsOpen
        clip: true
        spacing: 10
        model: chatClient.messages
        boundsBehavior: Flickable.StopAtBounds

        onCountChanged: positionViewAtEnd()

        delegate: Item {
            id: messageRow

            required property var modelData

            readonly property bool fromUser: modelData.role === "user"
            readonly property bool isError: modelData.role === "error"

            width: messageList.width
            height: bubble.height

            Rectangle {
                id: bubble

                anchors.right: messageRow.fromUser ? parent.right : undefined
                anchors.left: messageRow.fromUser ? undefined : parent.left
                width: Math.min(messageRow.width * 0.84, messageText.implicitWidth + 28)
                height: messageText.implicitHeight + 20
                radius: 10
                color: messageRow.isError ? "#2a1512"
                     : messageRow.fromUser ? "#1d3b52" : "#0c1d2b"
                border.width: 1
                border.color: messageRow.isError ? "#66b8443a"
                            : messageRow.fromUser ? "#446fbdbd" : "#14ffffff"

                Text {
                    id: messageText

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    wrapMode: Text.WordWrap
                    text: messageRow.modelData.text
                    color: messageRow.isError ? "#e7988f" : Theme.text
                    font.family: "DejaVu Sans"
                    font.pixelSize: 11
                    lineHeight: 1.35
                }
            }
        }
    }

    Text {
        anchors.centerIn: messageList
        visible: !chat.settingsOpen && chatClient.busy
        text: "sto pensando..."
        color: Theme.textFaint
        font.family: "DejaVu Sans"
        font.pixelSize: 10
        font.italic: true
    }

    Text {
        anchors.centerIn: messageList
        visible: !chat.settingsOpen && chatClient.messages.length === 0 && !chatClient.busy
                 && chatClient.status === "ready"
        text: "Nessun messaggio. Scrivi la prima domanda."
        color: Theme.textFaint
        font.family: "DejaVu Sans"
        font.pixelSize: 11
    }

    // --- compositore ---------------------------------------------------------
    Rectangle {
        id: composer

        anchors.bottom: parent.bottom
        width: parent.width
        height: chat.settingsOpen ? 0 : 56
        visible: !chat.settingsOpen
        color: "#071724"

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: "#12ffffff"
        }

        Rectangle {
            id: inputBox

            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 118
            height: 36
            radius: 8
            color: "#05121e"
            border.width: 1
            border.color: inputField.activeFocus ? "#88f9b234" : "#16ffffff"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: inputField.text === ""
                text: "Scrivi un messaggio..."
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 10
            }

            TextInput {
                id: inputField

                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: "#556fbdbd"
                selectedTextColor: "#031020"
                font.family: "DejaVu Sans"
                font.pixelSize: 11
                clip: true

                onAccepted: sendButton.send()
            }
        }

        Rectangle {
            id: sendButton

            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 88
            height: 36
            radius: 8
            color: !canSend ? "#132635"
                 : sendMouse.containsMouse ? "#ffc85a" : "#f9b234"
            border.width: 1
            border.color: canSend ? "#ffdf9e" : "#10ffffff"

            readonly property bool canSend: inputField.text.trim() !== "" && !chatClient.busy

            function send() {
                if (!canSend)
                    return
                chatClient.send(inputField.text)
                inputField.text = ""
            }

            Text {
                anchors.centerIn: parent
                text: chatClient.busy ? "..." : "Invia"
                color: sendButton.canSend ? "#031020" : "#4d6274"
                font.family: "DejaVu Sans"
                font.pixelSize: 10
                font.bold: true
            }

            MouseArea {
                id: sendMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sendButton.send()
            }
        }
    }
}
