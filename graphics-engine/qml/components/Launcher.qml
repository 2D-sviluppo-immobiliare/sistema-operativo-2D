import QtQuick

// Launcher laterale.
//
// Colonna di applicazioni sul bordo sinistro. Ogni voce entra con una folata
// da sinistra, sfalsata nel tempo, cosi' la comparsa legge come un movimento
// unico invece che come sei comparse separate.
Item {
    id: launcher

    property var model: []
    property var activeKeys: []
    property bool revealed: false

    signal activate(int index)

    readonly property int cellWidth: 78
    readonly property int cellHeight: 74
    readonly property int podSize: 42

    width: cellWidth
    height: column.implicitHeight

    function isActive(key) {
        return launcher.activeKeys.indexOf(key) !== -1
    }

    Column {
        id: column

        spacing: 4

        Repeater {
            model: launcher.model

            Item {
                id: cell

                required property var modelData
                required property int index

                readonly property bool active: launcher.isActive(modelData.key)
                property bool shown: false

                width: launcher.cellWidth
                height: launcher.cellHeight

                x: shown ? 0 : -70
                opacity: shown ? 1 : 0

                Behavior on x {
                    NumberAnimation { duration: 520; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
                }

                Timer {
                    interval: cell.index * 70
                    running: launcher.revealed
                    repeat: false
                    onTriggered: cell.shown = true
                }

                Rectangle {
                    id: pod

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    width: launcher.podSize
                    height: launcher.podSize
                    radius: width / 2
                    color: cell.active
                           ? "#e61b3348"
                           : (hover.containsMouse ? "#e616293a" : "#d90a1826")
                    border.width: 1
                    border.color: cell.active
                                  ? Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.85)
                                  : (hover.containsMouse
                                     ? Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.75)
                                     : Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.28))
                    scale: hover.containsMouse ? 1.10 : 1.0

                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.glyph
                        color: cell.modelData.accent || Theme.cyan
                        font.family: "DejaVu Sans"
                        font.pixelSize: cell.modelData.glyph === "</>" ? 12 : 15
                        font.bold: true
                    }
                }

                Text {
                    anchors.top: pod.bottom
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: cell.modelData.label
                    color: cell.active || hover.containsMouse ? Theme.text : Theme.textDim
                    font.family: "DejaVu Sans"
                    font.pixelSize: 8
                    elide: Text.ElideRight

                    // ombra netta: le etichette stanno sopra la fotografia
                    style: Text.Outline
                    styleColor: "#99000000"
                }

                MouseArea {
                    id: hover

                    anchors.fill: parent
                    z: 10
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: launcher.activate(index)
                }
            }
        }
    }
}
