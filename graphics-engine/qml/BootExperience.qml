import QtQuick

import "components"

// Schermata di avvio di 2D OS.
//
// Riproduce la composizione di riferimento: notte stellata, due orbite sottili
// (ciano e oro), il marchio al centro con alone, l'etichetta di sistema in alto
// e una linea di avanzamento discreta.
Item {
    id: boot

    signal finished()

    property string logoSource: Qt.resolvedUrl("../assets/logo-mark.png")

    // --- fondo ---------------------------------------------------------------
    Rectangle {
        id: sky

        anchors.fill: parent
        opacity: 0

        gradient: Gradient {
            GradientStop { position: 0.00; color: "#0a182b" }
            GradientStop { position: 0.35; color: "#102542" }
            GradientStop { position: 0.62; color: "#0e2138" }
            GradientStop { position: 1.00; color: "#070f1c" }
        }
    }

    // alone radiale al centro
    RadialGlow {
        id: coreGlow

        width: parent.height * 1.25
        height: width
        anchors.centerIn: parent
        tint: "#2f6d9e"
        strength: 0.30
        opacity: 0
    }

    // --- stelle --------------------------------------------------------------
    Item {
        id: stars

        anchors.fill: parent
        opacity: 0

        Repeater {
            model: 110

            Rectangle {
                required property int index

                readonly property real seed: ((index * 9301 + 49297) % 233280) / 233280

                width: 1 + seed * 2.2
                height: width
                radius: width / 2
                color: "#e8f4ff"
                opacity: 0.12 + seed * 0.55
                x: ((index * 7919 + 104729) % 1000) / 1000 * parent.width
                y: ((index * 6271 + 313) % 1000) / 1000 * parent.height
            }
        }
    }

    // --- orbite --------------------------------------------------------------
    Item {
        id: orbits

        anchors.fill: parent
        opacity: 0
        scale: 0.94

        Canvas {
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                const cx = width / 2
                const cy = height * 0.47

                // Traccia un'ellisse inclinata punto per punto: il tratto resta
                // di spessore uniforme e la posizione e' esattamente quella
                // calcolata, qualunque sia l'implementazione di ctx.ellipse().
                function traceEllipse(rx, ry, rot) {
                    const cos = Math.cos(rot)
                    const sin = Math.sin(rot)
                    const steps = 160
                    ctx.beginPath()
                    for (let i = 0; i <= steps; i++) {
                        const a = (i / steps) * Math.PI * 2
                        const px = Math.cos(a) * rx
                        const py = Math.sin(a) * ry
                        const x = cx + px * cos - py * sin
                        const y = cy + px * sin + py * cos
                        if (i === 0)
                            ctx.moveTo(x, y)
                        else
                            ctx.lineTo(x, y)
                    }
                    ctx.closePath()
                }

                function dot(rx, ry, rot, angle, color, size) {
                    const cos = Math.cos(rot)
                    const sin = Math.sin(rot)
                    const px = Math.cos(angle) * rx
                    const py = Math.sin(angle) * ry
                    const x = cx + px * cos - py * sin
                    const y = cy + px * sin + py * cos
                    ctx.beginPath()
                    ctx.fillStyle = color
                    ctx.arc(x, y, size, 0, Math.PI * 2)
                    ctx.fill()
                }

                ctx.lineWidth = 1

                // ellisse ciano principale
                ctx.strokeStyle = "rgba(111,189,189,0.55)"
                traceEllipse(width * 0.300, height * 0.215, -0.17)
                ctx.stroke()

                // ellisse ciano interna, piu' stretta
                ctx.strokeStyle = "rgba(111,189,189,0.20)"
                traceEllipse(width * 0.262, height * 0.130, 0.05)
                ctx.stroke()

                // ellisse oro, piu' bassa e inclinata in senso opposto
                ctx.strokeStyle = "rgba(226,181,96,0.48)"
                traceEllipse(width * 0.352, height * 0.118, 0.13)
                ctx.stroke()

                // punti luminosi sulle orbite
                dot(width * 0.300, height * 0.215, -0.17, Math.PI * 0.92, "rgba(111,189,189,0.95)", 3)
                dot(width * 0.300, height * 0.215, -0.17, Math.PI * 1.62, "rgba(111,189,189,0.70)", 2)
                dot(width * 0.352, height * 0.118, 0.13, Math.PI * 0.06, "rgba(249,178,52,0.90)", 2.5)
                dot(width * 0.352, height * 0.118, 0.13, Math.PI * 1.10, "rgba(249,178,52,0.65)", 1.8)
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }
    }

    // --- alone dietro al marchio --------------------------------------------
    RadialGlow {
        id: halo

        anchors.centerIn: parent
        width: parent.height * 0.80
        height: width
        tint: "#3f7fb0"
        strength: 0.22
        opacity: 0
    }

    // --- marchio -------------------------------------------------------------
    Image {
        id: logo

        anchors.centerIn: parent
        width: parent.width * 0.265
        source: boot.logoSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: 0
        scale: 0.92

        // Se il marchio trasparente non e' stato generato, si usa il PNG
        // originale: meglio un riquadro visibile che nessun logo.
        onStatusChanged: {
            if (status === Image.Error)
                source = Qt.resolvedUrl("../assets/logo.png")
        }
    }

    // --- etichetta di sistema -----------------------------------------------
    Text {
        id: systemLabel

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.075
        text: "PORTABLE INTELLIGENCE SYSTEM"
        color: "#9db3c7"
        font.family: "DejaVu Sans"
        font.pixelSize: 9
        font.letterSpacing: 3.6
        opacity: 0
    }

    // --- avanzamento ---------------------------------------------------------
    Item {
        id: loader

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.80
        width: parent.width * 0.24
        height: 14
        opacity: 0

        Rectangle {
            id: track

            anchors.bottom: parent.bottom
            width: parent.width
            height: 1.5
            radius: 0.75
            color: "#1fffffff"

            Rectangle {
                id: fill

                height: parent.height
                radius: parent.radius
                width: 0

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: "#55f9b234" }
                    GradientStop { position: 1.00; color: Theme.goldLoad }
                }
            }
        }

        Rectangle {
            id: head

            width: 5
            height: 5
            radius: 2.5
            color: "#ffe9b8"
            anchors.verticalCenter: track.verticalCenter
            x: fill.width - 2.5
            opacity: fill.width > 1 ? 1 : 0
        }
    }

    Text {
        id: loaderLabel

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: loader.bottom
        anchors.topMargin: 12
        text: "INIZIALIZZAZIONE 2D CORE"
        color: "#6d879c"
        font.family: "DejaVu Sans"
        font.pixelSize: 8
        font.letterSpacing: 4
        opacity: loader.opacity
    }

    // --- sequenza ------------------------------------------------------------
    SequentialAnimation {
        // Se la sequenza non e' in scena non deve nemmeno girare: senza questo
        // consumerebbe CPU per sette secondi dietro un desktop gia' visibile.
        running: boot.visible

        // Risveglio
        ParallelAnimation {
            NumberAnimation {
                target: sky; property: "opacity"
                from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: stars; property: "opacity"
                from: 0; to: 1; duration: 1200; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: coreGlow; property: "opacity"
                from: 0; to: 1; duration: 1400; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: systemLabel; property: "opacity"
                from: 0; to: 0.85; duration: 900; easing.type: Easing.OutCubic
            }
        }

        // Composizione delle orbite
        ParallelAnimation {
            NumberAnimation {
                target: orbits; property: "opacity"
                from: 0; to: 1; duration: 1000; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: orbits; property: "scale"
                from: 0.94; to: 1.0; duration: 1000; easing.type: Easing.OutCubic
            }
        }

        // Identita': il marchio entra
        ParallelAnimation {
            NumberAnimation {
                target: logo; property: "opacity"
                from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: logo; property: "scale"
                from: 0.92; to: 1.0; duration: 900; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: halo; property: "opacity"
                from: 0; to: 1; duration: 800; easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: loader; property: "opacity"
                from: 0; to: 1; duration: 500
            }
        }

        // Caricamento
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: logo; property: "scale"
                    from: 1.0; to: 1.018
                    duration: 1400; easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: logo; property: "scale"
                    from: 1.018; to: 1.0
                    duration: 1400; easing.type: Easing.InOutSine
                }
            }
            NumberAnimation {
                target: fill; property: "width"
                from: 0; to: track.width
                duration: 2600; easing.type: Easing.OutCubic
            }
        }

        // Transizione
        NumberAnimation {
            target: boot; property: "opacity"
            from: 1; to: 0; duration: 900; easing.type: Easing.InOutCubic
        }

        ScriptAction { script: boot.finished() }
    }
}
