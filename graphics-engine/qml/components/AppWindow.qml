import QtQuick

// Finestra applicativa del desktop 2D.
//
// Si comporta come una finestra di sistema: si trascina dalla barra del
// titolo, si ridimensiona da tutti i bordi e dagli angoli, si massimizza con
// il pulsante in alto a destra o con un doppio clic sul titolo, e si chiude
// con la ✕. Il clic in un punto qualsiasi la porta in primo piano.
//
// Il sistema non usa un window manager esterno: tutta questa logica e'
// disegnata e gestita in QML.
Item {
    id: win

    property string windowTitle: "Finestra"
    property string glyph: ""
    property color accent: Theme.gold
    property Component content: null
    property bool opened: true
    property bool minimized: false

    readonly property int minWidth: 300
    readonly property int minHeight: 200
    property bool maximized: false

    signal closeRequested()
    signal raised()
    signal minimizeRequested()

    // --- geometria -----------------------------------------------------------
    // Dimensioni e posizione memorizzate prima della massimizzazione.
    property real restoreX: 0
    property real restoreY: 0
    property real restoreWidth: 0
    property real restoreHeight: 0

    // Stato del trascinamento/ridimensionamento in corso.
    property real grabSceneX: 0
    property real grabSceneY: 0
    property real grabX: 0
    property real grabY: 0
    property real grabWidth: 0
    property real grabHeight: 0

    // Una finestra minimizzata sparisce dal desktop ma resta viva: al
    // ripristino ritrova geometria, stato massimizzato e contenuto.
    readonly property bool shown: opened && !minimized

    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.97
    visible: shown || opacity > 0.01

    // La tastiera deve arrivare al contenuto della finestra attiva: senza
    // questo la calcolatrice riceve i clic ma non i tasti.
    onShownChanged: {
        if (shown)
            win.focusContent()
    }

    function focusContent() {
        if (bodyLoader.item)
            bodyLoader.item.forceActiveFocus()
    }

    Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    function boundsWidth() { return win.parent ? win.parent.width : win.width }
    function boundsHeight() { return win.parent ? win.parent.height : win.height }

    function startGrab(sceneX, sceneY) {
        grabSceneX = sceneX
        grabSceneY = sceneY
        grabX = win.x
        grabY = win.y
        grabWidth = win.width
        grabHeight = win.height
    }

    // edges: 1 = sinistra, 2 = destra, 4 = alto, 8 = basso
    function applyResize(edges, dx, dy) {
        if (win.maximized)
            return

        var newX = grabX
        var newY = grabY
        var newW = grabWidth
        var newH = grabHeight

        if (edges & 1) {
            newW = Math.max(win.minWidth, grabWidth - dx)
            newX = grabX + (grabWidth - newW)
        }
        if (edges & 2) {
            newW = Math.max(win.minWidth, grabWidth + dx)
        }
        if (edges & 4) {
            newH = Math.max(win.minHeight, grabHeight - dy)
            newY = grabY + (grabHeight - newH)
        }
        if (edges & 8) {
            newH = Math.max(win.minHeight, grabHeight + dy)
        }

        win.x = newX
        win.y = newY
        win.width = newW
        win.height = newH
    }

    function toggleMaximize() {
        if (win.maximized) {
            win.x = win.restoreX
            win.y = win.restoreY
            win.width = win.restoreWidth
            win.height = win.restoreHeight
            win.maximized = false
            return
        }

        win.restoreX = win.x
        win.restoreY = win.y
        win.restoreWidth = win.width
        win.restoreHeight = win.height

        win.x = 0
        win.y = 44
        win.width = boundsWidth()
        win.height = Math.max(win.minHeight, boundsHeight() - 44)
        win.maximized = true
    }

    // --- ombra ---------------------------------------------------------------
    Rectangle {
        anchors.fill: frame
        anchors.margins: -4
        anchors.topMargin: -2
        radius: frame.radius + 4
        color: "#55000000"
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        radius: win.maximized ? 0 : 12
        color: "#f7071624"
        border.width: 1
        border.color: win.maximized
                      ? "#f9b23433"
                      : Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.30)

        Behavior on radius { NumberAnimation { duration: 140 } }

        // --- barra del titolo ---
        Rectangle {
            id: header

            width: parent.width
            height: 40
            radius: win.maximized ? 0 : 12
            color: "#f70d2033"

            // squadra gli angoli inferiori della barra
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height / 2
                color: parent.color
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.22)
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: win.glyph
                color: win.accent
                font.family: "DejaVu Sans"
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 38
                anchors.right: parent.right
                anchors.rightMargin: 128
                anchors.verticalCenter: parent.verticalCenter
                text: win.windowTitle
                color: Theme.text
                font.family: "DejaVu Sans"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.8
                elide: Text.ElideRight
            }

            // trascinamento della finestra
            MouseArea {
                id: titleDrag

                anchors.fill: parent
                anchors.rightMargin: 128

                cursorShape: win.maximized ? Qt.ArrowCursor : Qt.SizeAllCursor
                enabled: !win.maximized

                onPressed: function (mouse) {
                    win.raised()
                    win.focusContent()
                    var point = win.mapToItem(null, mouse.x, mouse.y)
                    win.startGrab(point.x, point.y)
                }
                onPositionChanged: function (mouse) {
                    if (!pressed)
                        return
                    var point = win.mapToItem(null, mouse.x, mouse.y)
                    var dx = point.x - win.grabSceneX
                    var dy = point.y - win.grabSceneY
                    var maxX = win.boundsWidth() - win.width
                    var maxY = win.boundsHeight() - 40
                    win.x = Math.max(0, Math.min(maxX, win.grabX + dx))
                    win.y = Math.max(0, Math.min(maxY, win.grabY + dy))
                }
                onDoubleClicked: win.toggleMaximize()
            }

            // clic sul titolo con finestra massimizzata: ripristina
            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: 128
                visible: win.maximized
                onClicked: {
                    win.raised()
                }
                onDoubleClicked: win.toggleMaximize()
            }
        }

        // --- pulsanti della finestra ---
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 7
            spacing: 6

            Rectangle {
                id: minimizeButton

                width: 26
                height: 26
                radius: 13
                color: minimizeMouse.containsMouse ? "#1d3a52" : "#1affffff"
                border.width: 1
                border.color: minimizeMouse.containsMouse ? "#6fbdbd" : "#20ffffff"

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -3
                    text: "\u2013"
                    color: Theme.text
                    font.family: "DejaVu Sans"
                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea {
                    id: minimizeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: win.minimizeRequested()
                }
            }

            Rectangle {
                id: maximizeButton

                width: 26
                height: 26
                radius: 13
                color: maximizeMouse.containsMouse ? "#1d3a52" : "#1affffff"
                border.width: 1
                border.color: maximizeMouse.containsMouse ? "#6fbdbd" : "#20ffffff"

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: win.maximized ? "\u2750" : "\u25A2"
                    color: Theme.text
                    font.family: "DejaVu Sans"
                    font.pixelSize: 10
                    font.bold: true
                }

                MouseArea {
                    id: maximizeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        win.raised()
                        win.toggleMaximize()
                    }
                }
            }

            Rectangle {
                id: closeButton

                width: 26
                height: 26
                radius: 13
                color: closeMouse.containsMouse ? "#c0483f" : "#1affffff"
                border.width: 1
                border.color: closeMouse.containsMouse ? "#e8695f" : "#20ffffff"

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "\u2715"
                    color: Theme.text
                    font.family: "DejaVu Sans"
                    font.pixelSize: 11
                    font.bold: true
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: win.closeRequested()
                }
            }
        }

        // --- contenuto ---
        Rectangle {
            id: body

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            color: "transparent"
            clip: true

            Loader {
                id: bodyLoader

                anchors.fill: parent
                sourceComponent: win.content
            }
        }

        // Porta in primo piano anche cliccando nel contenuto.
        // L'evento non viene accettato, quindi prosegue verso i controlli
        // sottostanti: la selezione e lo scorrimento restano intatti.
        MouseArea {
            anchors.fill: body
            z: 3
            onPressed: function (mouse) {
                win.raised()
                win.focusContent()
                mouse.accepted = false
            }
            onClicked: function (mouse) { mouse.accepted = false }
        }
    }

    // --- maniglie di ridimensionamento --------------------------------------
    // Sono fuori dalla cornice di proposito: non coprono il contenuto e
    // restano raggiungibili anche con la finestra massimizzata.
    component ResizeHandle: MouseArea {
        id: handle

        property int edges: 0

        cursorShape: edges === 1 || edges === 2 ? Qt.SizeHorCursor
                   : edges === 4 || edges === 8 ? Qt.SizeVerCursor
                   : edges === 1 + 8 || edges === 2 + 4 ? Qt.SizeBDiagCursor
                   : Qt.SizeFDiagCursor

        enabled: !win.maximized
        visible: enabled

        onPressed: function (mouse) {
            win.raised()
            var point = win.mapToItem(null, mouse.x, mouse.y)
            win.startGrab(point.x, point.y)
        }

        onPositionChanged: function (mouse) {
            if (!pressed)
                return
            var point = win.mapToItem(null, mouse.x, mouse.y)
            win.applyResize(edges, point.x - win.grabSceneX, point.y - win.grabSceneY)
        }
    }

    ResizeHandle { edges: 1; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 6; height: parent.height - 20 }
    ResizeHandle { edges: 2; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 6; height: parent.height - 20 }
    ResizeHandle { edges: 4; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; height: 6; width: parent.width - 20 }
    ResizeHandle { edges: 8; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; height: 6; width: parent.width - 20 }

    ResizeHandle { edges: 1 + 4; anchors.left: parent.left; anchors.top: parent.top; width: 14; height: 14 }
    ResizeHandle { edges: 2 + 4; anchors.right: parent.right; anchors.top: parent.top; width: 14; height: 14 }
    ResizeHandle { edges: 1 + 8; anchors.left: parent.left; anchors.bottom: parent.bottom; width: 14; height: 14 }
    ResizeHandle { edges: 2 + 8; anchors.right: parent.right; anchors.bottom: parent.bottom; width: 14; height: 14 }
}
