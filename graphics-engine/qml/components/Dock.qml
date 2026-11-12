import QtQuick

// Dock inferiore.
//
// Barra in vetro con le icone applicative. Sale dal basso all'avvio e
// ingrandisce leggermente l'icona sotto il puntatore.
Rectangle {
    id: dock

    property var model: []
    property var activeKeys: []
    property bool revealed: false

    signal activate(int index)

    function isActive(key) {
        return dock.activeKeys.indexOf(key) !== -1
    }

    width: row.implicitWidth + 26
    height: 52
    radius: height / 2
    color: "#c4061422"
    border.width: 1
    border.color: Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.22)

    y: revealed ? 0 : 30
    opacity: revealed ? 1 : 0

    Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }

    // riflesso superiore
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.82
        height: parent.height * 0.42
        radius: height / 2

        gradient: Gradient {
            GradientStop { position: 0.00; color: "#1affffff" }
            GradientStop { position: 1.00; color: "#00ffffff" }
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: dock.model

            Item {
                id: slot

                required property var modelData
                required property int index

                readonly property bool active: dock.isActive(modelData.key)

                width: 34
                height: 34

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: slot.active
                           ? "#ee1b3348"
                           : (hover.containsMouse ? "#ee16293a" : "#aa0d1d2e")
                    border.width: 1
                    border.color: slot.active
                                  ? Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.8)
                                  : Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.2)
                    scale: hover.containsMouse ? 1.16 : 1.0

                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 130 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: slot.modelData.glyph
                    color: slot.modelData.accent || Theme.cyan
                    font.family: "DejaVu Sans"
                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea {
                    id: hover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dock.activate(slot.index)
                }
            }
        }
    }
}
