import QtQuick

// File manager del desktop 2D.
//
// Tutta la logica di filesystem sta nel backend Python (``fileBrowser``): qui
// c'e' solo la presentazione. Le operazioni distruttive chiedono conferma e le
// scritture sono limitate dal backend alla home e ai dispositivi rimovibili.
Item {
    id: manager

    property var selection: []
    property var clipboard: []
    property string clipboardMode: ""
    property string notice: ""

    readonly property bool hasSelection: selection.length > 0
    readonly property bool single: selection.length === 1

    function selectedPaths() {
        var out = []
        for (var i = 0; i < selection.length; i++) {
            var path = fileBrowser.pathAt(selection[i])
            if (path !== "")
                out.push(path)
        }
        return out
    }

    function showNotice(text) {
        notice = text
        noticeTimer.restart()
    }

    function clickRow(row, modifiers) {
        if (modifiers & Qt.ControlModifier) {
            var next = selection.slice()
            var at = next.indexOf(row)
            if (at === -1)
                next.push(row)
            else
                next.splice(at, 1)
            selection = next
        } else if (modifiers & Qt.ShiftModifier && selection.length > 0) {
            var first = Math.min(selection[selection.length - 1], row)
            var last = Math.max(selection[selection.length - 1], row)
            var range = []
            for (var i = first; i <= last; i++)
                range.push(i)
            selection = range
        } else {
            selection = [row]
        }
    }

    function resetSelection() {
        selection = []
    }

    Timer {
        id: noticeTimer
        interval: 4500
        onTriggered: manager.notice = ""
    }

    Connections {
        target: fileBrowser
        function onCurrentPathChanged() {
            pathField.text = fileBrowser.currentPath
            manager.resetSelection()
            manager.clipboard = manager.clipboard
        }
        function onLastErrorChanged() {
            if (fileBrowser.lastError !== "")
                manager.showNotice(fileBrowser.lastError)
        }
    }

    // --- barra degli strumenti ----------------------------------------------
    Rectangle {
        id: toolbar

        width: parent.width
        height: 46
        color: "#071724"

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            component ToolButton: Rectangle {
                id: button

                property string label: ""
                property bool enabledButton: true
                signal clicked()

                width: Math.max(56, labelText.width + 20)
                height: 30
                radius: 7
                color: !enabledButton ? "#0a1622"
                     : buttonMouse.containsMouse ? "#17304a" : "#0d1e2e"
                border.width: 1
                border.color: enabledButton ? "#1fffffff" : "#0cffffff"

                Text {
                    id: labelText
                    anchors.centerIn: parent
                    text: button.label
                    color: button.enabledButton ? Theme.textDim : "#3f5568"
                    font.family: "DejaVu Sans"
                    font.pixelSize: 10
                }

                MouseArea {
                    id: buttonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: button.enabledButton
                    onClicked: button.clicked()
                }
            }

            ToolButton {
                label: "\u2191 Su"
                enabledButton: fileBrowser.canGoUp
                onClicked: fileBrowser.goUp()
            }

            ToolButton {
                label: "\u2302 Home"
                onClicked: fileBrowser.goHome()
            }

            ToolButton {
                label: "\u21BB"
                onClicked: fileBrowser.refresh()
            }
        }

        Rectangle {
            id: pathBar

            anchors.left: parent.left
            anchors.leftMargin: 210
            anchors.right: searchBox.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 30
            radius: 7
            color: "#05121e"
            border.width: 1
            border.color: pathField.activeFocus ? "#88f9b234" : "#16ffffff"

            TextInput {
                id: pathField

                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: "#556fbdbd"
                selectedTextColor: "#031020"
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 11
                clip: true

                Component.onCompleted: text = fileBrowser.currentPath
                onAccepted: {
                    if (!fileBrowser.goTo(text))
                        pathField.text = fileBrowser.currentPath
                }
            }
        }

        Rectangle {
            id: searchBox

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 190
            height: 30
            radius: 7
            color: "#05121e"
            border.width: 1
            border.color: fileBrowser.searching ? "#88f9b234" : "#16ffffff"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: searchField.text === ""
                text: "Cerca in questa cartella..."
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 9
            }

            TextInput {
                id: searchField

                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: "#556fbdbd"
                selectedTextColor: "#031020"
                font.family: "DejaVu Sans"
                font.pixelSize: 10
                clip: true

                onTextChanged: searchTimer.restart()
            }

            Timer {
                id: searchTimer
                interval: 350
                onTriggered: {
                    if (searchField.text.length >= 2)
                        fileBrowser.search(searchField.text)
                    else if (searchField.text.length === 0)
                        fileBrowser.cancelSearch()
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#12ffffff"
        }
    }

    // --- barra laterale delle destinazioni ----------------------------------
    Rectangle {
        id: placesPanel

        anchors.top: toolbar.bottom
        anchors.left: parent.left
        anchors.bottom: footer.top
        width: 168
        color: "#06131f"

        ListView {
            anchors.fill: parent
            anchors.margins: 8
            model: fileBrowser.places
            clip: true
            spacing: 2

            delegate: Rectangle {
                required property var modelData

                width: ListView.view.width
                height: 30
                radius: 6
                color: placeMouse.containsMouse ? "#13283c" : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: modelData.glyph
                        color: "#f9b234"
                        font.family: "DejaVu Sans"
                        font.pixelSize: 12
                    }

                    Text {
                        text: modelData.label
                        color: Theme.textDim
                        font.family: "DejaVu Sans"
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: placeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        fileBrowser.goTo(modelData.path)
                        searchField.text = ""
                    }
                }
            }
        }

        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: "#0effffff"
        }
    }

    // --- elenco dei file -----------------------------------------------------
    Item {
        id: fileArea

        anchors.top: toolbar.bottom
        anchors.left: placesPanel.right
        anchors.right: parent.right
        anchors.bottom: footer.top

        // intestazione delle colonne
        Rectangle {
            id: headerRow

            width: parent.width
            height: 26
            color: "#071724"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: fileBrowser.searching
                      ? "RISULTATI DELLA RICERCA"
                      : "NOME"
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 8
                font.letterSpacing: 1.6
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 130
                anchors.verticalCenter: parent.verticalCenter
                text: "MODIFICATO"
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 8
                font.letterSpacing: 1.6
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                text: "DIMENSIONE"
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 8
                font.letterSpacing: 1.6
            }
        }

        ListView {
            id: fileList

            anchors.top: headerRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            model: fileBrowser
            reuseItems: true

            delegate: Rectangle {
                id: row

                required property int index
                required property string name
                required property string icon
                required property string sizeText
                required property string modified

                readonly property bool selected: manager.selection.indexOf(index) !== -1

                width: ListView.view.width
                height: 30
                color: selected ? "#1b3348"
                     : rowMouse.containsMouse ? "#0f2434" : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    FileIcon {
                        kind: row.icon
                        baseSize: 15
                        width: 20
                    }

                    Text {
                        text: row.name
                        color: row.selected ? Theme.text : "#c7d8e6"
                        font.family: "DejaVu Sans"
                        font.pixelSize: 11
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 130
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modified
                    color: Theme.textFaint
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    width: 84
                    horizontalAlignment: Text.AlignRight
                    text: row.sizeText
                    color: Theme.textFaint
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: function (mouse) { manager.clickRow(row.index, mouse.modifiers) }
                    onDoubleClicked: fileBrowser.enter(row.index)
                }
            }
        }

        // cartella vuota
        Text {
            anchors.centerIn: fileList
            visible: fileBrowser.count === 0
            text: fileBrowser.searching ? "Nessun risultato." : "Cartella vuota."
            color: Theme.textFaint
            font.family: "DejaVu Sans"
            font.pixelSize: 11
        }
    }

    // --- barra inferiore -----------------------------------------------------
    Rectangle {
        id: footer

        anchors.bottom: parent.bottom
        width: parent.width
        height: 44
        color: "#071724"

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: "#12ffffff"
        }

        Text {
            id: statusText

            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 240
            elide: Text.ElideRight
            text: manager.notice !== ""
                  ? manager.notice
                  : manager.hasSelection
                    ? manager.selection.length + " selezionati"
                    : fileBrowser.count + " elementi"
            color: manager.notice !== "" ? "#e8a05f" : Theme.textFaint
            font.family: "DejaVu Sans"
            font.pixelSize: 9
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            component ActionButton: Rectangle {
                id: action

                property string label: ""
                property bool enabledButton: true
                property bool danger: false
                signal clicked()

                width: Math.max(64, actionText.width + 20)
                height: 28
                radius: 7
                color: !enabledButton ? "#0a1622"
                     : actionMouse.containsMouse
                       ? (danger ? "#a8433a" : "#17304a")
                       : "#0d1e2e"
                border.width: 1
                border.color: enabledButton ? (danger ? "#66b8443a" : "#1fffffff") : "#0cffffff"

                Text {
                    id: actionText
                    anchors.centerIn: parent
                    text: action.label
                    color: action.enabledButton ? (action.danger ? "#e7988f" : Theme.textDim) : "#3f5568"
                    font.family: "DejaVu Sans"
                    font.pixelSize: 9
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: action.enabledButton
                    onClicked: action.clicked()
                }
            }

            ActionButton {
                label: "+ Cartella"
                enabledButton: fileBrowser.writable
                onClicked: newFolderDialog.open("Nuova cartella")
            }

            ActionButton {
                label: "Rinomina"
                enabledButton: manager.single && fileBrowser.writable
                onClicked: renameDialog.open(fileList.model
                    ? fileBrowser.pathAt(manager.selection[0]).split("/").pop() : "")
            }

            ActionButton {
                label: "Copia"
                enabledButton: manager.hasSelection
                onClicked: {
                    manager.clipboard = manager.selectedPaths()
                    manager.clipboardMode = "copy"
                    manager.showNotice(manager.clipboard.length + " elementi copiati")
                }
            }

            ActionButton {
                label: "Sposta"
                enabledButton: manager.hasSelection
                onClicked: {
                    manager.clipboard = manager.selectedPaths()
                    manager.clipboardMode = "move"
                    manager.showNotice(manager.clipboard.length + " elementi pronti da spostare")
                }
            }

            ActionButton {
                label: "Incolla"
                enabledButton: manager.clipboard.length > 0 && fileBrowser.writable
                onClicked: {
                    var errors = manager.clipboardMode === "copy"
                            ? fileBrowser.copyPaths(manager.clipboard, fileBrowser.currentPath)
                            : fileBrowser.movePaths(manager.clipboard, fileBrowser.currentPath)
                    if (errors === 0) {
                        manager.showNotice("Operazione completata")
                        manager.clipboard = []
                        manager.clipboardMode = ""
                    }
                }
            }

            ActionButton {
                label: "Cestina"
                danger: true
                enabledButton: manager.hasSelection && fileBrowser.writable
                onClicked: trashDialog.open("")
            }

            ActionButton {
                label: "Info"
                enabledButton: manager.hasSelection
                onClicked: {
                    var info = fileBrowser.infoAt(manager.selection[0])
                    infoDialog.open("")
                    // il testo viene composto subito dopo l'apertura
                    infoDialog.message =
                        "Percorso: " + info.path + "\n" +
                        "Tipo: " + info.kind + "\n" +
                        "Dimensione: " + info.size + "\n" +
                        "Modificato: " + info.modified + "\n" +
                        "Lettura: " + (info.readable ? "consentita" : "negata") + "\n" +
                        "Scrittura: " + (info.writable ? "consentita" : "negata")
                }
            }
        }
    }

    // --- dialoghi ------------------------------------------------------------
    Dialog2D {
        id: newFolderDialog
        title: "NUOVA CARTELLA"
        message: "Inserisci il nome della cartella."
        withInput: true
        placeholder: "nome cartella"
        confirmLabel: "Crea"

        onAccepted: function (text) {
            close()
            if (fileBrowser.makeDirectory(text))
                manager.showNotice("Cartella creata")
        }
        onCancelled: close()
    }

    Dialog2D {
        id: renameDialog
        title: "RINOMINA"
        message: "Nuovo nome per l'elemento selezionato."
        withInput: true
        confirmLabel: "Rinomina"

        onAccepted: function (text) {
            close()
            if (fileBrowser.renameAt(manager.selection[0], text))
                manager.showNotice("Rinominato")
        }
        onCancelled: close()
    }

    Dialog2D {
        id: trashDialog
        title: "SPOSTARE NEL CESTINO?"
        danger: false
        confirmLabel: "Sposta"

        onAccepted: function () {
            close()
            var count = manager.selection.length
            var errors = fileBrowser.trashPaths(manager.selectedPaths())
            if (errors === 0)
                manager.showNotice(count + " elementi nel cestino")
            manager.resetSelection()
        }
        onCancelled: close()

        Component.onCompleted: message =
            "Gli elementi selezionati finiranno nel cestino e potranno essere ripristinati."
    }

    Dialog2D {
        id: infoDialog
        title: "INFORMAZIONI"
        confirmLabel: "Chiudi"
        cancelLabel: ""
        onAccepted: close()
        onCancelled: close()
    }
}
