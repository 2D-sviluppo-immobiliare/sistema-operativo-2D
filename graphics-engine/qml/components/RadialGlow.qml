import QtQuick

// Alone radiale morbido.
//
// Un Rectangle con gradiente lineare e angoli arrotondati lascia un bordo
// circolare netto, perche' il gradiente scorre solo in verticale. Qui il
// gradiente e' davvero radiale: si spegne in ogni direzione senza scalini.
Item {
    id: glow

    property color tint: "#f9b234"
    property real strength: 0.30
    // frazione del raggio in cui il colore e' pieno
    property real core: 0.0
    // frazione del raggio in cui il colore e' svanito
    property real edge: 1.0

    Canvas {
        id: painter

        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const cx = width / 2
            const cy = height / 2
            const radius = Math.min(width, height) / 2
            const c = glow.tint

            const gradient = ctx.createRadialGradient(
                        cx, cy, radius * glow.core,
                        cx, cy, radius * glow.edge)

            gradient.addColorStop(0.00, Qt.rgba(c.r, c.g, c.b, glow.strength))
            gradient.addColorStop(0.35, Qt.rgba(c.r, c.g, c.b, glow.strength * 0.55))
            gradient.addColorStop(0.70, Qt.rgba(c.r, c.g, c.b, glow.strength * 0.16))
            gradient.addColorStop(1.00, Qt.rgba(c.r, c.g, c.b, 0.0))

            ctx.fillStyle = gradient
            ctx.fillRect(0, 0, width, height)
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }
}
