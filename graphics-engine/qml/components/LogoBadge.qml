import QtQuick

// Marchio ufficiale in alto a destra, con alone luminoso.
Item {
    id: badge

    property string logoSource: Qt.resolvedUrl("../../assets/logo-mark.png")
    property bool revealed: false
    property real logoWidth: 96

    width: logoWidth
    height: logoWidth * 0.961

    // Scrim scuro: la fotografia di sfondo ha zone molto chiare (facciata
    // illuminata) e il marchio, che e' chiaro a sua volta, sparirebbe.
    RadialGlow {
        anchors.centerIn: parent
        width: parent.width * 1.9
        height: width
        tint: "#04101c"
        strength: 0.60
        opacity: badge.revealed ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    }

    RadialGlow {
        anchors.centerIn: parent
        width: parent.width * 2.8
        height: width
        tint: "#6fb6e8"
        strength: 0.20
        opacity: badge.revealed ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    }

    RadialGlow {
        anchors.centerIn: parent
        width: parent.width * 1.9
        height: width
        tint: "#f9b234"
        strength: 0.10
        opacity: badge.revealed ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.OutCubic } }
    }

    Image {
        anchors.fill: parent
        source: badge.logoSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true

        opacity: badge.revealed ? 1 : 0
        scale: badge.revealed ? 1 : 0.90

        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }

        // Se il marchio trasparente non c'e', si usa il PNG originale.
        onStatusChanged: {
            if (status === Image.Error && source.toString().indexOf("logo-mark") !== -1)
                source = Qt.resolvedUrl("../../assets/logo.png")
        }
    }
}
