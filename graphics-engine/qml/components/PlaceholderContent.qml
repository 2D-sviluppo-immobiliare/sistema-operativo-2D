import QtQuick

// Contenuto segnaposto per le applicazioni che non hanno ancora un'app nativa.
// Mantiene la stessa grammatica visiva del resto del sistema.
Item {
    id: placeholder

    property string heading: ""
    property string subtitle: ""
    property string glyph: ""
    property color accent: Theme.gold

    Item {
        id: block

        anchors.centerIn: parent
        width: parent.width
        height: circle.height + 16 + headingText.height + 10 + subtitleText.height

        Rectangle {
            id: circle

            anchors.horizontalCenter: parent.horizontalCenter
            width: 92
            height: 92
            radius: 46
            color: Qt.rgba(placeholder.accent.r, placeholder.accent.g, placeholder.accent.b, 0.10)
            border.width: 1
            border.color: Qt.rgba(placeholder.accent.r, placeholder.accent.g, placeholder.accent.b, 0.35)

            Text {
                anchors.centerIn: parent
                text: placeholder.glyph
                color: placeholder.accent
                font.family: "DejaVu Sans"
                font.pixelSize: 28
                font.bold: true
            }
        }

        Text {
            id: headingText

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: circle.bottom
            anchors.topMargin: 16
            text: placeholder.heading
            color: Theme.text
            font.family: "DejaVu Sans"
            font.pixelSize: 13
            font.bold: true
            font.letterSpacing: 2.4
        }

        Text {
            id: subtitleText

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: headingText.bottom
            anchors.topMargin: 10
            width: parent.width * 0.82
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: placeholder.subtitle
            color: Theme.textFaint
            font.family: "DejaVu Sans"
            font.pixelSize: 10
            lineHeight: 1.35
        }
    }
}
