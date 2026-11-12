import QtQuick
import QtQuick.Window

// Test minimale di input: nessuna shell, nessun window manager.
// Se questo non riceve click, il problema e' nell'ambiente X/Qt.
Window {
    id: w
    width: 640
    height: 400
    visible: true
    color: "#7a1010"
    title: "MINITEST"

    Component.onCompleted: console.log("[MINI] finestra creata")

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPressed: function (m) { console.log("[MINI] PRESSED", m.x, m.y) }
            onClicked: function (m) { console.log("[MINI] CLICKED", m.x, m.y) }
        }
    }

    Text {
        anchors.centerIn: parent
        text: "MINITEST"
        color: "white"
        font.pixelSize: 40
    }
}
