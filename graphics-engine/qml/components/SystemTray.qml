import QtQuick

// System tray in basso a destra: rete, audio, data e ora.
//
// Ogni controllo apre un pannello reale: la rete elenca le interfacce lette da
// /sys/class/net, l'audio muove il volume di sistema, l'orologio alterna ora e
// data. Nessun elemento e' solo decorativo.
Rectangle {
    id: tray

    property string popup: ""
    property int volume: 60
    property var interfaces: []

    // --- stato Wi-Fi ---------------------------------------------------------
    property var wifiNetworks: []
    property string pendingSsid: ""
    property bool askingPassword: false
    property string passwordText: ""
    property string networkError: ""
    property bool scanning: false

    readonly property bool online: typeof networkInfo !== "undefined"
                                   ? networkInfo.online
                                   : false

    readonly property bool wifiAvailable: typeof networkInfo !== "undefined"
                                         ? networkInfo.wifiAvailable
                                         : false

    width: row.implicitWidth + 22
    height: 38
    radius: 19
    color: "#b3061422"
    border.width: 1
    border.color: Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.22)

    function refresh() {
        if (typeof systemInfo === "undefined")
            return
        if (typeof networkInfo !== "undefined")
            tray.interfaces = networkInfo.details()
        tray.volume = systemInfo.volume()
    }

    function toggle(name) {
        tray.popup = tray.popup === name ? "" : name
        tray.askingPassword = false
        tray.networkError = ""
        if (tray.popup === "wifi")
            tray.scan()
    }

    function scan() {
        if (typeof networkInfo === "undefined" || !tray.wifiAvailable)
            return
        tray.scanning = true
        tray.wifiNetworks = networkInfo.scanWifi()
        tray.scanning = false
        if (networkInfo.lastError !== "")
            tray.networkError = networkInfo.lastError
    }

    function chooseNetwork(network) {
        tray.networkError = ""
        if (network.connected)
            return
        if (network.secured) {
            tray.pendingSsid = network.ssid
            tray.passwordText = ""
            tray.askingPassword = true
            return
        }
        tray.connectTo(network.ssid, "")
    }

    function connectTo(ssid, password) {
        tray.networkError = ""
        const result = networkInfo.connectWifi(ssid, password)
        if (result && result.ok) {
            tray.askingPassword = false
            tray.pendingSsid = ""
            tray.passwordText = ""
            tray.refresh()
            tray.scan()
        } else {
            tray.networkError = result && result.error ? result.error : "connessione non riuscita"
        }
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: tray.refresh()
    }

    // --- orologio ------------------------------------------------------------
    // Giorni e mesi scritti a mano: cosi' la data resta in italiano anche su
    // un sistema dove i locale non sono stati generati.
    readonly property var dayNames: ["dom", "lun", "mar", "mer", "gio", "ven", "sab"]
    readonly property var monthNames: ["gen", "feb", "mar", "apr", "mag", "giu",
                                       "lug", "ago", "set", "ott", "nov", "dic"]

    function pad(value) {
        return value < 10 ? "0" + value : String(value)
    }

    function updateClock() {
        const now = new Date()
        clockTime.text = tray.pad(now.getHours()) + ":" + tray.pad(now.getMinutes())
        clockDate.text = tray.dayNames[now.getDay()] + " " + now.getDate()
                         + " " + tray.monthNames[now.getMonth()]
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: tray.updateClock()
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 3

        // --- rete ---
        Item {
            id: wifiButton

            width: 32
            height: 28

            Canvas {
                id: wifiCanvas

                anchors.fill: parent
                antialiasing: true

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2
                    const cy = height * 0.66
                    const color = tray.popup === "wifi"
                                ? "#f9b234"
                                : (tray.online ? "#6fbdbd" : "#8fa9bd")

                    ctx.strokeStyle = color
                    ctx.lineWidth = 1.5
                    ctx.lineCap = "round"
                    for (let i = 1; i <= 3; i++) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, i * 4.0, Math.PI * 1.28, Math.PI * 1.72)
                        ctx.stroke()
                    }
                    ctx.fillStyle = color
                    ctx.beginPath()
                    ctx.arc(cx, cy - 1.5, 1.5, 0, Math.PI * 2)
                    ctx.fill()
                }

                Connections {
                    target: tray
                    function onPopupChanged() { wifiCanvas.requestPaint() }
                    function onOnlineChanged() { wifiCanvas.requestPaint() }
                }

                Component.onCompleted: requestPaint()
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tray.toggle("wifi")
            }
        }

        // --- audio ---
        Item {
            id: audioButton

            width: 32
            height: 28

            Canvas {
                id: audioCanvas

                anchors.fill: parent
                antialiasing: true

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2
                    const cy = height / 2
                    const color = tray.popup === "audio" ? "#f9b234" : "#8fa9bd"

                    ctx.fillStyle = color
                    ctx.beginPath()
                    ctx.moveTo(cx - 6, cy - 3)
                    ctx.lineTo(cx - 2, cy - 3)
                    ctx.lineTo(cx + 2, cy - 7)
                    ctx.lineTo(cx + 2, cy + 7)
                    ctx.lineTo(cx - 2, cy + 3)
                    ctx.lineTo(cx - 6, cy + 3)
                    ctx.closePath()
                    ctx.fill()

                    ctx.strokeStyle = color
                    ctx.lineWidth = 1.4
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.arc(cx + 3, cy, 5, -Math.PI * 0.32, Math.PI * 0.32)
                    ctx.stroke()
                }

                Connections {
                    target: tray
                    function onPopupChanged() { audioCanvas.requestPaint() }
                }

                Component.onCompleted: requestPaint()
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tray.toggle("audio")
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 18
            color: "#1affffff"
        }

        // --- ora e data ---
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                id: clockTime

                text: ""
                color: Theme.text
                font.family: "DejaVu Sans"
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                id: clockDate

                text: ""
                color: Theme.textDim
                font.family: "DejaVu Sans"
                font.pixelSize: 8
            }
        }

        // --- stato di sistema ---
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: tray.online ? Theme.green : Theme.textFaint
        }
    }

    // --- pannello ---
    Rectangle {
        id: popupPanel

        anchors.bottom: parent.top
        anchors.bottomMargin: 10
        anchors.right: parent.right
        width: 232
        height: tray.popup === "audio" ? 96
              : tray.askingPassword ? 128
              : 46 + Math.max(1, tray.interfaces.length) * 16
                + (tray.wifiAvailable ? 22 + Math.max(1, tray.wifiNetworks.length) * 19 : 0)
                + (tray.networkError !== "" ? 16 : 0)
        radius: 12
        color: "#f2081726"
        border.width: 1
        border.color: Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.28)
        visible: tray.popup !== ""
        opacity: tray.popup !== "" ? 1 : 0
        scale: tray.popup !== "" ? 1 : 0.96

        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        transformOrigin: Item.BottomRight

        Text {
            id: popupTitle

            x: 14
            y: 11
            text: tray.popup === "wifi" ? "RETE" : "AUDIO"
            color: Theme.textDim
            font.family: "DejaVu Sans"
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 2
        }

        // --- elenco interfacce ---
        Column {
            id: ifaceColumn

            x: 14
            y: 28
            width: parent.width - 28
            spacing: 3
            visible: tray.popup === "wifi" && !tray.askingPassword

            Text {
                visible: tray.interfaces.length === 0
                text: "Nessuna interfaccia rilevata"
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 10
            }

            Repeater {
                model: tray.interfaces

                Row {
                    id: ifaceRow

                    required property var modelData

                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: ifaceRow.modelData.connected ? Theme.green : Theme.textFaint
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 84
                        elide: Text.ElideRight
                        text: ifaceRow.modelData.label
                        color: Theme.text
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (ifaceRow.modelData.kind === "wifi" ? "Wi-Fi"
                             : ifaceRow.modelData.kind === "ethernet" ? "Ethernet"
                             : ifaceRow.modelData.kind)
                              + (ifaceRow.modelData.address !== ""
                                 ? "  " + ifaceRow.modelData.address
                                 : "  " + ifaceRow.modelData.state)
                        color: ifaceRow.modelData.connected ? Theme.textDim : Theme.textFaint
                        font.family: "DejaVu Sans"
                        font.pixelSize: 9
                    }
                }
            }
        }

        // --- reti Wi-Fi disponibili ------------------------------------------
        Column {
            id: networksColumn

            x: 14
            anchors.top: ifaceColumn.bottom
            anchors.topMargin: 8
            width: parent.width - 28
            spacing: 1
            visible: tray.popup === "wifi" && !tray.askingPassword && tray.wifiAvailable

            Text {
                text: tray.scanning ? "RICERCA RETI..." : "RETI DISPONIBILI"
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 7
                font.letterSpacing: 1.4
            }

            Text {
                visible: tray.wifiNetworks.length === 0
                text: tray.scanning ? "scansione in corso" : "nessuna rete trovata"
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 9
            }

            Repeater {
                model: tray.wifiNetworks

                Rectangle {
                    id: netRow

                    required property var modelData

                    width: parent.width
                    height: 17
                    radius: 4
                    color: netMouse.containsMouse ? "#17304a" : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            text: netRow.modelData.connected ? "\u25CF" : "\u25CB"
                            color: netRow.modelData.connected ? Theme.green : Theme.textFaint
                            font.family: "DejaVu Sans"
                            font.pixelSize: 7
                        }

                        Text {
                            width: 110
                            elide: Text.ElideRight
                            text: netRow.modelData.ssid
                            color: netRow.modelData.connected ? Theme.text : Theme.textDim
                            font.family: "DejaVu Sans"
                            font.pixelSize: 9
                        }

                        Text {
                            text: netRow.modelData.secured ? netRow.modelData.security : ""
                            color: Theme.textFaint
                            font.family: "DejaVu Sans"
                            font.pixelSize: 6
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: netRow.modelData.signal + "%"
                        color: Theme.textFaint
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 8
                    }

                    MouseArea {
                        id: netMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: tray.chooseNetwork(netRow.modelData)
                    }
                }
            }
        }

        // --- password Wi-Fi --------------------------------------------------
        Column {
            id: passwordColumn

            x: 14
            y: 30
            width: parent.width - 28
            spacing: 6
            visible: tray.popup === "wifi" && tray.askingPassword

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: "Password per " + tray.pendingSsid
                color: Theme.text
                font.family: "DejaVu Sans"
                font.pixelSize: 9
            }

            Rectangle {
                width: parent.width
                height: 26
                radius: 6
                color: "#05121e"
                border.width: 1
                border.color: passwordField.activeFocus ? "#88f9b234" : "#16ffffff"

                TextInput {
                    id: passwordField

                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.text
                    font.family: "DejaVu Sans"
                    font.pixelSize: 10
                    clip: true
                    focus: tray.askingPassword

                    onTextChanged: tray.passwordText = text
                    onAccepted: tray.connectTo(tray.pendingSsid, tray.passwordText)
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 6

                Rectangle {
                    width: 64
                    height: 22
                    radius: 5
                    color: cancelNetMouse.containsMouse ? "#17304a" : "#0d1e2e"
                    border.width: 1
                    border.color: "#1fffffff"

                    Text {
                        anchors.centerIn: parent
                        text: "Annulla"
                        color: Theme.textDim
                        font.family: "DejaVu Sans"
                        font.pixelSize: 8
                    }

                    MouseArea {
                        id: cancelNetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            tray.askingPassword = false
                            tray.passwordText = ""
                        }
                    }
                }

                Rectangle {
                    width: 74
                    height: 22
                    radius: 5
                    color: connectNetMouse.containsMouse ? "#ffc85a" : "#f9b234"

                    Text {
                        anchors.centerIn: parent
                        text: "Connetti"
                        color: "#031020"
                        font.family: "DejaVu Sans"
                        font.pixelSize: 8
                        font.bold: true
                    }

                    MouseArea {
                        id: connectNetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: tray.connectTo(tray.pendingSsid, tray.passwordText)
                    }
                }
            }
        }

        // --- errore di rete --------------------------------------------------
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: parent.width - 28
            elide: Text.ElideRight
            visible: tray.networkError !== ""
            text: tray.networkError
            color: "#e7988f"
            font.family: "DejaVu Sans"
            font.pixelSize: 7
        }

        // --- volume ---
        Item {
            x: 14
            y: 34
            width: parent.width - 28
            height: 44
            visible: tray.popup === "audio"

            Rectangle {
                id: sliderTrack

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: "#1fffffff"

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * tray.volume / 100

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.00; color: "#f9b23455" }
                        GradientStop { position: 1.00; color: Theme.gold }
                    }
                }

                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    color: Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(parent.width - width, parent.width * tray.volume / 100 - width / 2))
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -12
                    cursorShape: Qt.PointingHandCursor

                    function applyVolume(mx) {
                        const relative = Math.max(0, Math.min(sliderTrack.width, mx - 12))
                        const value = Math.round(relative / sliderTrack.width * 100)
                        tray.volume = value
                        if (typeof systemInfo !== "undefined")
                            systemInfo.setVolume(value)
                    }

                    onPressed: function (mouse) { applyVolume(mouse.x) }
                    onPositionChanged: function (mouse) {
                        if (pressed)
                            applyVolume(mouse.x)
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: sliderTrack.top
                anchors.bottomMargin: 6
                text: tray.volume + "%"
                color: Theme.text
                font.family: "DejaVu Sans"
                font.pixelSize: 9
                font.bold: true
            }
        }
    }
}
