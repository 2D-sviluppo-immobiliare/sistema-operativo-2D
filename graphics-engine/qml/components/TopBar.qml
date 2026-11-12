import QtQuick

// Barra superiore del desktop.
// A sinistra l'identita' di sistema, a destra lo stato della sessione.
Rectangle {
    id: bar

    height: 44
    color: "#cc040e1a"

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "#00f9b234" }
            GradientStop { position: 0.18; color: "#33f9b234" }
            GradientStop { position: 0.72; color: "#226fbdbd" }
            GradientStop { position: 1.00; color: "#00f9b234" }
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 26
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "2D OS"
            color: Theme.text
            font.family: "DejaVu Sans"
            font.pixelSize: 15
            font.bold: true
            font.letterSpacing: 1.5
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "PERSONAL WORKSPACE"
            color: Theme.textFaint
            font.family: "DejaVu Sans"
            font.pixelSize: 8
            font.letterSpacing: 2.6
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 26
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "SESSIONE LOCALE"
            color: Theme.goldSoft
            font.family: "DejaVu Sans"
            font.pixelSize: 8
            font.letterSpacing: 2.2
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 3
            radius: 1.5
            color: Theme.gold
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "ONLINE"
            color: Theme.gold
            font.family: "DejaVu Sans"
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 2.2
        }
    }
}
