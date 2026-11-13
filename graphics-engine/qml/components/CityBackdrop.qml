import QtQuick

// Sfondo del desktop: notte architettonica.
//
// Tutto il paesaggio e' disegnato in modo procedurale: nessuna immagine da
// caricare, nessun fotogramma da animare. Cosi' il desktop resta fluido anche
// senza accelerazione grafica.
Item {
    id: backdrop

    // Quota della linea d'acqua rispetto all'altezza.
    property real horizonRatio: 0.66
    readonly property real horizonY: Math.round(height * horizonRatio)

    // --- cielo ---------------------------------------------------------------
    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop { position: 0.00; color: "#07192c" }
            GradientStop { position: 0.26; color: "#0c2d4c" }
            GradientStop { position: 0.50; color: "#12456d" }
            GradientStop { position: 0.66; color: "#0b2f4c" }
            GradientStop { position: 0.67; color: "#082238" }
            GradientStop { position: 1.00; color: "#020710" }
        }
    }

    // --- stelle --------------------------------------------------------------
    Item {
        anchors.fill: parent
        // solo la fascia alta del cielo
        height: backdrop.horizonY * 0.95

        Repeater {
            model: 78

            Rectangle {
                required property int index

                // sequenza deterministica: stessa disposizione a ogni avvio
                readonly property real seed: ((index * 9301 + 49297) % 233280) / 233280

                width: 1 + seed * 1.8
                height: width
                radius: width / 2
                color: "#e6f3ff"
                opacity: 0.10 + seed * 0.45
                x: ((index * 7919 + 104729) % 1000) / 1000 * parent.width
                y: ((index * 6271 + 31) % 1000) / 1000 * parent.height
            }
        }
    }

    // --- alone caldo sopra l'orizzonte --------------------------------------
    // Ampio e basso: deve leggersi come foschia calda sulla linea d'acqua,
    // non come un disco al centro della scena.
    RadialGlow {
        id: warmGlow

        width: backdrop.width * 0.92
        height: width * 0.44
        x: (backdrop.width - width) / 2 - backdrop.width * 0.03
        y: backdrop.horizonY - height * 0.62
        tint: "#ffc76b"
        strength: 0.13
    }

    // --- skyline, luci e riflessi -------------------------------------------
    Canvas {
        id: city

        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const hz = backdrop.horizonY
            const W = width

            // Silhouette degli edifici: [x, larghezza, altezza] in frazioni.
            // Il gruppo di sinistra resta basso: la dock verticale deve restare
            // leggibile sopra il profilo della citta'.
            const towers = [
                [0.000, 0.048, 0.050], [0.050, 0.030, 0.034],
                [0.148, 0.040, 0.046], [0.192, 0.026, 0.028],
                [0.622, 0.040, 0.130], [0.665, 0.052, 0.196],
                [0.720, 0.038, 0.158], [0.762, 0.060, 0.262],
                [0.826, 0.034, 0.132], [0.864, 0.058, 0.302],
                [0.926, 0.040, 0.188], [0.968, 0.032, 0.120]
            ]

            // Corpi degli edifici, dal piu' lontano al piu' vicino.
            for (let i = 0; i < towers.length; i++) {
                const t = towers[i]
                const x = t[0] * W
                const w = t[1] * W
                const h = t[2] * backdrop.height
                const y = hz - h

                const grad = ctx.createLinearGradient(0, y, 0, hz)
                grad.addColorStop(0.0, "#0e2b45")
                grad.addColorStop(1.0, "#050f1b")
                ctx.fillStyle = grad
                ctx.fillRect(x, y, w, h)

                // bordo luminoso sul lato sinistro
                ctx.fillStyle = "rgba(150,196,224,0.16)"
                ctx.fillRect(x, y, 1, h)

                // finestre illuminate, disposte a griglia
                const cols = Math.max(2, Math.round(w / 13))
                const rows = Math.max(3, Math.round(h / 16))
                const padX = w * 0.18
                const padY = h * 0.10
                const stepX = (w - padX * 2) / cols
                const stepY = (h - padY * 2) / rows

                for (let c = 0; c < cols; c++) {
                    for (let r = 0; r < rows; r++) {
                        const n = (i * 37 + c * 11 + r * 3) % 10
                        if (n > 4)
                            continue
                        const lit = n % 3 === 0
                        ctx.fillStyle = lit
                                ? "rgba(255,205,120," + (0.42 + (n % 4) * 0.12) + ")"
                                : "rgba(120,175,205," + (0.10 + (n % 5) * 0.04) + ")"
                        ctx.fillRect(x + padX + c * stepX, y + padY + r * stepY,
                                     Math.max(1.5, stepX * 0.42),
                                     Math.max(1.5, stepY * 0.36))
                    }
                }
            }

            // Fascia d'acqua: riflessi verticali sotto ogni edificio.
            for (let i = 0; i < towers.length; i++) {
                const t = towers[i]
                const x = t[0] * W + t[1] * W * 0.5
                const w = t[1] * W * 0.62
                const len = backdrop.height * (0.05 + (i % 4) * 0.022)

                const grad = ctx.createLinearGradient(0, hz, 0, hz + len)
                grad.addColorStop(0.0, "rgba(255,200,120,0.13)")
                grad.addColorStop(0.45, "rgba(150,190,215,0.05)")
                grad.addColorStop(1.0, "rgba(0,0,0,0)")
                ctx.fillStyle = grad
                ctx.fillRect(x - w / 2, hz, w, len)
            }

            // Strada illuminata al centro della scena: si allarga verso chi
            // guarda, con un nucleo caldo subito sotto l'orizzonte.
            const roadGrad = ctx.createLinearGradient(0, hz, 0, backdrop.height)
            roadGrad.addColorStop(0.0, "rgba(255,218,158,0.34)")
            roadGrad.addColorStop(0.25, "rgba(249,178,52,0.14)")
            roadGrad.addColorStop(0.65, "rgba(249,178,52,0.05)")
            roadGrad.addColorStop(1.0, "rgba(0,0,0,0)")
            ctx.fillStyle = roadGrad
            ctx.beginPath()
            ctx.moveTo(W * 0.462, hz)
            ctx.lineTo(W * 0.538, hz)
            ctx.lineTo(W * 0.640, backdrop.height)
            ctx.lineTo(W * 0.360, backdrop.height)
            ctx.closePath()
            ctx.fill()

            // nucleo luminoso sulla linea d'acqua
            const coreGrad = ctx.createRadialGradient(W * 0.5, hz, 0, W * 0.5, hz, W * 0.16)
            coreGrad.addColorStop(0.0, "rgba(255,232,190,0.45)")
            coreGrad.addColorStop(0.45, "rgba(249,178,52,0.16)")
            coreGrad.addColorStop(1.0, "rgba(0,0,0,0)")
            ctx.fillStyle = coreGrad
            ctx.fillRect(W * 0.34, hz - W * 0.16, W * 0.32, W * 0.16)
        }

        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // --- foschia sopra l'orizzonte ------------------------------------------
    // Fa arretrare gli edifici e ammorbidisce il distacco con l'acqua.
    Rectangle {
        y: backdrop.horizonY - 118
        width: parent.width
        height: 120

        gradient: Gradient {
            GradientStop { position: 0.00; color: "#00143054" }
            GradientStop { position: 0.70; color: "#2a1a3c5e" }
            GradientStop { position: 1.00; color: "#5c17395a" }
        }
    }

    // --- filo d'oro sull'orizzonte ------------------------------------------
    Rectangle {
        y: backdrop.horizonY - 1
        x: parent.width * 0.10
        width: parent.width * 0.80
        height: 1.5

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "#00000000" }
            GradientStop { position: 0.42; color: "#55f9b234" }
            GradientStop { position: 0.52; color: "#ccffe4ab" }
            GradientStop { position: 1.00; color: "#00000000" }
        }
    }

    // --- sfondo ufficiale ----------------------------------------------------
    // La fotografia del cliente copre il paesaggio procedurale. Se l'asset non
    // e' presente (immagine costruita senza wallpaper) resta visibile la citta'
    // disegnata sopra, quindi il desktop non rimane mai vuoto.
    //
    // Due strati: il primo riempie lo schermo ritagliando (riempimento), il
    // secondo mostra la fotografia INTERA. Su schermi non 16:9 il riempimento
    // evita le bande nere e il secondo strato evita il taglio del soggetto:
    // nessuna delle due cose e' possibile con un solo Image.
    Item {
        anchors.fill: parent
        visible: wallpaper.status === Image.Ready

        Image {
            anchors.fill: parent
            source: wallpaper.source
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: true
            cache: true
            opacity: 0.85
        }

        Rectangle {
            anchors.fill: parent
            color: "#b3040e1a"
        }
    }

    Image {
        id: wallpaper

        anchors.fill: parent
        source: Qt.resolvedUrl("../../assets/wallpaper-villa.jpg")
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: true

        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        onStatusChanged: console.log("[2D WALLPAPER]", status,
                                     status === Image.Ready ? "READY" : "",
                                     status === Image.Error ? "LOAD ERROR" : "",
                                     source)
    }

    // --- velatura: scurisce i bordi e tiene leggibili le icone --------------
    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop { position: 0.00; color: "#55000d1e" }
            GradientStop { position: 0.30; color: "#00000d1e" }
            GradientStop { position: 0.70; color: "#00000d1e" }
            GradientStop { position: 1.00; color: "#99000d1e" }
        }
    }

    // --- velo laterale sinistro ---------------------------------------------
    // Garantisce il contrasto delle etichette della dock verticale.
    Rectangle {
        width: backdrop.width * 0.17
        height: parent.height

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "#a6040e1a" }
            GradientStop { position: 0.55; color: "#3d040e1a" }
            GradientStop { position: 1.00; color: "#00040e1a" }
        }
    }
}
