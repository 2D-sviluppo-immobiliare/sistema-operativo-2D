import QtQuick

import "components"

// Desktop 2D.
//
// Ordine di sovrapposizione, dal fondo verso l'alto:
//   1. sfondo (fotografia ufficiale, con fallback procedurale)
//   2. logo ufficiale in alto a destra
//   3. launcher laterale, dock inferiore, pannello hardware, system tray
//   4. finestre applicative
Item {
    id: desktop

    // --- stato delle finestre ------------------------------------------------
    property var openState: ({
        "browser": false,
        "code": false,
        "documenti": false,
        "chat": false,
        "cestino": false,
        "missing": false,
        "calc": false,
        "note": false
    })

    // Applicazione esterna richiesta ma non installata (browser, editor).
    property string missingKey: "browser"

    property real cpu: 0
    property real ram: 0
    property real disk: 0

    // Gli elementi di cornice hanno misure pensate per 800 px di altezza.
    // Oltre quella soglia crescono, cosi' a 1080p non diventano francobolli.
    readonly property real uiScale: Math.max(1.0, Math.min(1.55, height / 800))

    // le animazioni di ingresso partono quando il desktop e' davvero visibile
    property bool revealed: false

    // --- launcher laterale ---------------------------------------------------
    readonly property var launcherApps: [
        { key: "browser",   label: "Chrome",    glyph: "\u25C9",  accent: "#6fbdbd",
          external: "browser", argument: "about:blank" },
        { key: "code",      label: "VS Code",   glyph: "</>",     accent: "#5aa9e6",
          external: "code" },
        { key: "documenti", label: "Documenti", glyph: "\u25A4",  accent: "#f9b234" },
        { key: "chat",      label: "Chat2D",    glyph: "AI",      accent: "#a78bfa" },
        { key: "terminale", label: "Terminale", glyph: ">_",      accent: "#4bc47a",
          shell: true, exec: "xterm -fa 'DejaVu Sans Mono' -fs 11 -geometry 96x28+150+90 -bg '#081726' -fg '#dbe9f2'" },
        { key: "cestino",   label: "Cestino",   glyph: "\u232B",  accent: "#8fa9bd" }
    ]

    // --- dock inferiore ------------------------------------------------------
    // Le stesse voci del launcher piu' gli strumenti nativi del sistema.
    readonly property var dockApps: [
        { key: "browser",   label: "Chrome",       glyph: "\u25C9",  accent: "#6fbdbd",
          external: "browser", argument: "about:blank" },
        { key: "code",      label: "VS Code",      glyph: "</>",     accent: "#5aa9e6",
          external: "code" },
        { key: "documenti", label: "Documenti",    glyph: "\u25A4",  accent: "#f9b234" },
        { key: "chat",      label: "Chat2D",       glyph: "AI",      accent: "#a78bfa" },
        { key: "terminale", label: "Terminale",    glyph: ">_",      accent: "#4bc47a",
          shell: true, exec: "xterm -fa 'DejaVu Sans Mono' -fs 11 -geometry 96x28+150+90 -bg '#081726' -fg '#dbe9f2'" },
        { key: "calc",      label: "Calcolatrice", glyph: "\u00B1",  accent: "#f9b234" },
        { key: "note",      label: "Note",         glyph: "\u270E",  accent: "#6fbdbd" },
        { key: "cestino",   label: "Cestino",      glyph: "\u232B",  accent: "#8fa9bd" }
    ]

    readonly property var activeKeys: desktop.computeActive()

    function computeActive() {
        var out = []
        for (var k in desktop.openState) {
            if (desktop.openState[k])
                out.push(k)
        }
        return out
    }

    function setOpen(key, value) {
        if (desktop.openState[key] === value)
            return
        var next = {}
        for (var k in desktop.openState)
            next[k] = desktop.openState[k]
        next[key] = value
        desktop.openState = next
    }

    function toggleApp(key) {
        var willOpen = !desktop.openState[key]
        desktop.setOpen(key, willOpen)
        desktop.setMinimized(key, false)
        if (willOpen)
            desktop.raise(key)
    }

    // --- minimizzazione ------------------------------------------------------
    // Una finestra ridotta a icona resta aperta (e conserva il suo stato), ma
    // sparisce dal desktop. Torna cliccando la sua icona nella dock.
    property var minimizedState: ({
        "browser": false,
        "code": false,
        "documenti": false,
        "chat": false,
        "cestino": false,
        "missing": false,
        "calc": false,
        "note": false
    })

    function setMinimized(key, value) {
        if (desktop.minimizedState[key] === value)
            return
        var next = {}
        for (var k in desktop.minimizedState)
            next[k] = desktop.minimizedState[k]
        next[key] = value
        desktop.minimizedState = next
    }

    // Alt+Tab: porta in cima la finestra visibile piu' in basso.
    // Con "reverse" si scorre in senso opposto (Alt+Shift+Tab).
    function cycleWindow(reverse) {
        var visibleOnes = []
        for (var i = 0; i < desktop.stack.length; i++) {
            var key = desktop.stack[i]
            if (desktop.openState[key] && !desktop.minimizedState[key])
                visibleOnes.push(key)
        }
        if (visibleOnes.length < 2)
            return
        if (reverse)
            desktop.lower(visibleOnes[visibleOnes.length - 1])
        else
            desktop.raise(visibleOnes[0])
    }

    // Porta in fondo alla pila la finestra indicata: serve ad Alt+Shift+Tab.
    function lower(id) {
        var next = [id]
        for (var i = 0; i < desktop.stack.length; i++) {
            if (desktop.stack[i] !== id)
                next.push(desktop.stack[i])
        }
        desktop.stack = next
    }

    // Chiude la finestra in primo piano (Alt+F4).
    function closeTopWindow() {
        for (var i = desktop.stack.length - 1; i >= 0; i--) {
            var key = desktop.stack[i]
            if (desktop.openState[key] && !desktop.minimizedState[key]) {
                desktop.setOpen(key, false)
                return
            }
        }
    }

    // --- ordine di sovrapposizione delle finestre ----------------------------
    // L'ultima voce dell'elenco e' la finestra in primo piano. Le z restano
    // sotto 42, cioe' sotto la barra, il launcher, la dock e il tray.
    property var stack: ["missing", "documenti", "chat", "cestino", "calc", "note"]

    function zOf(id) {
        var index = desktop.stack.indexOf(id)
        return 10 + (index < 0 ? 0 : index)
    }

    function raise(id) {
        var next = []
        for (var i = 0; i < desktop.stack.length; i++) {
            if (desktop.stack[i] !== id)
                next.push(desktop.stack[i])
        }
        next.push(id)
        desktop.stack = next
    }

    function activate(entry) {
        if (!entry)
            return

        if (entry.shell) {
            if (typeof launcher !== "undefined")
                launcher.toggle(entry.label, entry.exec)
            return
        }

        if (entry.external) {
            // Chrome e VS Code sono applicazioni vere: se il binario c'e' si
            // avvia, altrimenti si spiega come installarlo. Nessuna finestra
            // finta in nessuno dei due casi.
            if (apps.isAvailable(entry.external)) {
                var argument = entry.argument || ""
                if (entry.external === "code" && argument === "")
                    argument = apps.projectPath()
                apps.start(entry.external, argument)
                return
            }
            desktop.missingKey = entry.external
            desktop.setOpen("missing", true)
            desktop.raise("missing")
            return
        }

        // Applicazione interna gia' aperta: se e' ridotta a icona si
        // ripristina, altrimenti la si riduce a icona.
        if (desktop.openState[entry.key]) {
            if (desktop.minimizedState[entry.key]) {
                desktop.setMinimized(entry.key, false)
                desktop.raise(entry.key)
            } else {
                desktop.setMinimized(entry.key, true)
            }
            return
        }

        desktop.toggleApp(entry.key)
    }

    // --- ingresso del desktop ------------------------------------------------
    Timer {
        id: revealTimer

        interval: 150
        repeat: false
        onTriggered: {
            if (desktop.visible)
                desktop.revealed = true
        }
    }

    Component.onCompleted: revealTimer.start()
    onVisibleChanged: {
        if (visible && !desktop.revealed)
            revealTimer.restart()
    }

    // --- 1. sfondo -----------------------------------------------------------
    CityBackdrop {
        anchors.fill: parent
    }

    // --- 2. logo -------------------------------------------------------------
    LogoBadge {
        id: logoBadge

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 58
        anchors.rightMargin: 30
        revealed: desktop.revealed
        logoWidth: Math.max(84, Math.min(124, desktop.width * 0.082))
        scale: desktop.uiScale
        transformOrigin: Item.TopRight
        // Decorazione del desktop, non della barra: sta sotto le finestre.
        z: 6
    }

    // --- 3a. pannello hardware flottante ------------------------------------
    HardwarePanel {
        id: hardware

        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.top: parent.top
        anchors.topMargin: 58 + logoBadge.height * desktop.uiScale + 30 * desktop.uiScale
        cpu: desktop.cpu
        ram: desktop.ram
        disk: desktop.disk
        opacity: desktop.revealed ? 1 : 0
        scale: desktop.uiScale
        transformOrigin: Item.TopRight
        // Sotto le finestre: e' un widget del desktop, non della barra.
        z: 6

        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }

    // --- 3b. barra superiore -------------------------------------------------
    TopBar {
        width: parent.width / desktop.uiScale
        anchors.top: parent.top
        anchors.left: parent.left
        scale: desktop.uiScale
        transformOrigin: Item.TopLeft
        z: 44
    }

    // --- 3c. launcher laterale ----------------------------------------------
    Launcher {
        id: launcherColumn

        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 14
        model: desktop.launcherApps
        activeKeys: desktop.activeKeys
        revealed: desktop.revealed
        scale: desktop.uiScale
        transformOrigin: Item.Left
        z: 42

        onActivate: function (index) { desktop.activate(desktop.launcherApps[index]) }
    }

    // --- 3d. dock inferiore --------------------------------------------------
    Dock {
        id: bottomDock

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        model: desktop.dockApps
        activeKeys: desktop.activeKeys
        revealed: desktop.revealed
        scale: desktop.uiScale
        transformOrigin: Item.Bottom
        z: 42

        onActivate: function (index) { desktop.activate(desktop.dockApps[index]) }
    }

    // --- 3e. system tray -----------------------------------------------------
    SystemTray {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 30
        anchors.bottomMargin: 24
        opacity: desktop.revealed ? 1 : 0
        scale: desktop.uiScale
        transformOrigin: Item.BottomRight
        z: 46

        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }

    // --- 4. finestre ---------------------------------------------------------
    AppWindow {
        id: missingWindow

        x: 260; y: 130
        width: 600; height: 430
        z: desktop.zOf("missing")
        windowTitle: desktop.missingKey === "code" ? "VISUAL STUDIO CODE" : "GOOGLE CHROME"
        glyph: "\u26A0"
        accent: "#e0b455"
        opened: desktop.openState.missing
        onCloseRequested: desktop.setOpen("missing", false)
        onRaised: desktop.raise("missing")
        minimized: desktop.minimizedState["missing"]
        onMinimizeRequested: desktop.setMinimized("missing", true)

        content: Component {
            MissingApp {
                appKey: desktop.missingKey
            }
        }
    }

    AppWindow {
        id: documentiWindow

        x: 150; y: 108
        width: 860; height: 520
        z: desktop.zOf("documenti")
        windowTitle: "DOCUMENTI"
        glyph: "\u25A4"
        accent: "#f9b234"
        opened: desktop.openState.documenti
        onCloseRequested: desktop.setOpen("documenti", false)
        onRaised: desktop.raise("documenti")
        minimized: desktop.minimizedState["documenti"]
        onMinimizeRequested: desktop.setMinimized("documenti", true)

        onOpenedChanged: {
            if (opened)
                fileBrowser.refresh()
        }

        content: Component { FileManager { } }
    }

    AppWindow {
        id: chatWindow

        x: 690; y: 168
        width: 460; height: 500
        z: desktop.zOf("chat")
        windowTitle: "CHAT 2D"
        glyph: "AI"
        accent: "#a78bfa"
        opened: desktop.openState.chat
        onCloseRequested: desktop.setOpen("chat", false)
        onRaised: desktop.raise("chat")
        minimized: desktop.minimizedState["chat"]
        onMinimizeRequested: desktop.setMinimized("chat", true)

        content: Component { Chat2D { } }
    }

    AppWindow {
        id: cestinoWindow

        x: 228; y: 148
        width: 800; height: 430
        z: desktop.zOf("cestino")
        windowTitle: "CESTINO"
        glyph: "\u232B"
        accent: "#8fa9bd"
        opened: desktop.openState.cestino
        onCloseRequested: desktop.setOpen("cestino", false)
        onRaised: desktop.raise("cestino")
        minimized: desktop.minimizedState["cestino"]
        onMinimizeRequested: desktop.setMinimized("cestino", true)

        content: Component { TrashBin { } }
    }

    AppWindow {
        id: calcWindow

        x: 640; y: 150
        width: 300; height: 444
        z: desktop.zOf("calc")
        windowTitle: "CALCOLATRICE"
        glyph: "\u00B1"
        accent: "#f9b234"
        opened: desktop.openState.calc
        onCloseRequested: desktop.setOpen("calc", false)
        onRaised: desktop.raise("calc")
        minimized: desktop.minimizedState["calc"]
        onMinimizeRequested: desktop.setMinimized("calc", true)

        content: Component { Calculator { } }
    }

    AppWindow {
        id: noteWindow

        x: 300; y: 230
        width: 420; height: 320
        z: desktop.zOf("note")
        windowTitle: "BLOCCO NOTE"
        glyph: "\u270E"
        accent: "#6fbdbd"
        opened: desktop.openState.note
        onCloseRequested: desktop.setOpen("note", false)
        onRaised: desktop.raise("note")
        minimized: desktop.minimizedState["note"]
        onMinimizeRequested: desktop.setMinimized("note", true)

        content: Component { Notes { } }
    }

    // --- telemetria ----------------------------------------------------------
    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (typeof systemInfo === "undefined")
                return
            const stats = systemInfo.stats()
            desktop.cpu = stats.cpu
            desktop.ram = stats.ram
            desktop.disk = stats.disk
        }
    }
}
