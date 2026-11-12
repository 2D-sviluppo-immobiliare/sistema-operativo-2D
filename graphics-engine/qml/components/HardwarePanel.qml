import QtQuick

// Pannello hardware flottante.
//
// Tre indicatori circolari (CPU, RAM, DISCO) con riempimento blu/oro e la
// pillola di stato dell'ambiente. I valori arrivano da systemInfo.stats().
Rectangle {
    id: panel

    property real cpu: 0
    property real ram: 0
    property real disk: 0

    width: 196
    height: 138
    radius: 14
    color: "#cc061422"
    border.width: 1
    border.color: Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.24)

    // riflesso in alto, da' l'effetto vetro
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 4
        height: 34
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.00; color: "#14ffffff" }
            GradientStop { position: 1.00; color: "#00ffffff" }
        }
    }

    Text {
        id: title

        x: 14
        y: 12
        text: "SISTEMA 2D"
        color: Theme.text
        font.family: "DejaVu Sans"
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 1
    }

    Text {
        anchors.left: title.left
        anchors.top: title.bottom
        anchors.topMargin: 1
        text: "Monitor hardware"
        color: Theme.textFaint
        font.family: "DejaVu Sans"
        font.pixelSize: 8
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 42
        spacing: 6

        component Gauge: Item {
            id: gauge

            property real value: 0
            property string caption: ""
            property color tint: Theme.gold

            width: 58
            height: 56

            Canvas {
                id: ring

                width: 42
                height: 42
                anchors.horizontalCenter: parent.horizontalCenter
                antialiasing: true

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()

                    const cx = width / 2
                    const cy = height / 2
                    const r = 16
                    const start = -Math.PI / 2
                    const sweep = Math.PI * 2 * Math.max(0, Math.min(1, gauge.value))

                    // fondo dell'anello: blu notte
                    ctx.lineWidth = 3
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.strokeStyle = "rgba(111,189,189,0.16)"
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.stroke()

                    if (sweep > 0.01) {
                        ctx.beginPath()
                        ctx.strokeStyle = gauge.tint
                        ctx.arc(cx, cy, r, start, start + sweep)
                        ctx.stroke()
                    }
                }

                Connections {
                    target: gauge
                    function onValueChanged() { ring.requestPaint() }
                }

                Component.onCompleted: requestPaint()
            }

            Text {
                anchors.centerIn: ring
                text: Math.round(gauge.value * 100) + "%"
                color: Theme.text
                font.family: "DejaVu Sans"
                font.pixelSize: 9
                font.bold: true
            }

            Text {
                anchors.top: ring.bottom
                anchors.topMargin: 3
                anchors.horizontalCenter: parent.horizontalCenter
                text: gauge.caption
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 7
                font.letterSpacing: 1.1
            }
        }

        Gauge { value: panel.cpu;  caption: "CPU";   tint: "#f9b234" }
        Gauge { value: panel.ram;  caption: "RAM";   tint: "#6fbdbd" }
        Gauge { value: panel.disk; caption: "DISCO"; tint: "#e0b455" }
    }

    Rectangle {
        id: statusPill

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        anchors.bottomMargin: 9
        height: 18
        radius: 9
        color: "#55123c28"
        border.width: 1
        border.color: Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.45)

        Row {
            anchors.centerIn: parent
            spacing: 5

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                height: 5
                radius: 2.5
                color: Theme.green
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "AMBIENTE OPERATIVO"
                color: "#8fe0ac"
                font.family: "DejaVu Sans"
                font.pixelSize: 7
                font.letterSpacing: 1.6
            }
        }
    }
}
