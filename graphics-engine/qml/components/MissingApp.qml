import QtQuick

// Avviso di applicazione mancante.
//
// Quando un'applicazione esterna non e' installata la shell non finge nulla:
// mostra il nome, il comando di installazione e un pulsante per riprovare.
Item {
    id: missing

    property string appKey: "browser"
    property string title: ""
    property string instructions: ""
    property var info: ({})

    signal retryRequested()

    function reload() {
        info = apps.info(appKey)
        title = info.name || appKey
        instructions = info.install || ""
    }

    Component.onCompleted: reload()
    onAppKeyChanged: reload()

    Item {
        id: block

        anchors.centerIn: parent
        width: parent.width
        height: circle.height + 16 + heading.height + 10 + body.height + 18 + retryButton.height

        Rectangle {
            id: circle

            anchors.horizontalCenter: parent.horizontalCenter
            width: 84
            height: 84
            radius: 42
            color: "#1a1408"
            border.width: 1
            border.color: "#55e0b455"

            Text {
                anchors.centerIn: parent
                text: "\u26A0"
                color: "#e0b455"
                font.family: "DejaVu Sans"
                font.pixelSize: 30
                font.bold: true
            }
        }

        Text {
            id: heading

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: circle.bottom
            anchors.topMargin: 16
            text: missing.title + " non è installato"
            color: Theme.text
            font.family: "DejaVu Sans"
            font.pixelSize: 13
            font.bold: true
            font.letterSpacing: 0.8
        }

        Text {
            id: body

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: heading.bottom
            anchors.topMargin: 10
            width: parent.width * 0.86
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: missing.instructions
            color: Theme.textDim
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 9
            lineHeight: 1.45
        }

        Rectangle {
            id: retryButton

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: body.bottom
            anchors.topMargin: 18
            width: 140
            height: 32
            radius: 8
            color: retryMouse.containsMouse ? "#17304a" : "#0d1e2e"
            border.width: 1
            border.color: "#1fffffff"

            Text {
                anchors.centerIn: parent
                text: "Ho installato, riprova"
                color: Theme.textDim
                font.family: "DejaVu Sans"
                font.pixelSize: 9
            }

            MouseArea {
                id: retryMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    missing.reload()
                    missing.retryRequested()
                }
            }
        }
    }
}
