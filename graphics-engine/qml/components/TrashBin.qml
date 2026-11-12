import QtQuick

// Cestino del desktop 2D.
//
// Legge e scrive il vero cestino freedesktop, quindi i file finiti qui dalla
// shell convivono con quelli spostati da altre applicazioni.
Item {
    id: bin

    property int currentRow: -1
    property string notice: ""

    function showNotice(text) {
        notice = text
        noticeTimer.restart()
    }

    Timer {
        id: noticeTimer
        interval: 4000
        onTriggered: bin.notice = ""
    }

    Connections {
        target: trashModel
        function onChanged() { bin.currentRow = -1 }

        function onLastErrorChanged() {
            if (trashModel.lastError !== "")
                bin.showNotice(trashModel.lastError)
        }
    }

    Component.onCompleted: trashModel.refresh()
    onVisibleChanged: {
        if (visible)
            trashModel.refresh()
    }

    // --- intestazione --------------------------------------------------------
    Rectangle {
        id: header

        width: parent.width
        height: 46
        color: "#071724"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "CESTINO"
            color: Theme.text
            font.family: "DejaVu Sans"
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 2
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 92
            anchors.verticalCenter: parent.verticalCenter
            text: trashModel.count + (trashModel.count === 1 ? " elemento" : " elementi")
            color: Theme.textFaint
            font.family: "DejaVu Sans"
            font.pixelSize: 9
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#12ffffff"
        }
    }

    // --- elenco --------------------------------------------------------------
    Item {
        id: listArea

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top

        Rectangle {
            id: columnsBar

            width: parent.width
            height: 26
            color: "#071724"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "NOME"
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 8
                font.letterSpacing: 1.6
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 220
                anchors.verticalCenter: parent.verticalCenter
                text: "POSIZIONE ORIGINALE"
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 8
                font.letterSpacing: 1.6
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "ELIMINATO"
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 8
                font.letterSpacing: 1.6
            }
        }

        ListView {
            id: trashList

            anchors.top: columnsBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            model: trashModel
            reuseItems: true

            delegate: Rectangle {
                id: row

                required property int index
                required property string name
                required property string originalPath
                required property string deletedAt
                required property string sizeText
                required property bool isDir

                readonly property bool selected: bin.currentRow === index

                width: ListView.view.width
                height: 32
                color: selected ? "#1b3348"
                     : rowMouse.containsMouse ? "#0f2434" : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 196
                    spacing: 10

                    FileIcon {
                        kind: row.isDir ? "folder" : "file"
                        baseSize: 14
                        width: 18
                    }

                    Text {
                        width: 160
                        elide: Text.ElideMiddle
                        text: row.name
                        color: row.selected ? Theme.text : "#c7d8e6"
                        font.family: "DejaVu Sans"
                        font.pixelSize: 11
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 220
                    anchors.right: deletedColumn.left
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideMiddle
                    text: row.originalPath
                    color: Theme.textFaint
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                }

                Text {
                    id: deletedColumn
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 130
                    horizontalAlignment: Text.AlignRight
                    text: row.deletedAt + "   " + row.sizeText
                    color: Theme.textFaint
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bin.currentRow = row.index
                    onDoubleClicked: restoreDialog.open("")
                }
            }
        }

        Column {
            anchors.centerIn: parent
            visible: trashModel.count === 0
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u232B"
                color: "#2c4557"
                font.family: "DejaVu Sans"
                font.pixelSize: 42
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Il cestino è vuoto."
                color: Theme.textFaint
                font.family: "DejaVu Sans"
                font.pixelSize: 11
            }
        }
    }

    // --- barra inferiore -----------------------------------------------------
    Rectangle {
        id: footer

        anchors.bottom: parent.bottom
        width: parent.width
        height: 46
        color: "#071724"

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: "#12ffffff"
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 420
            elide: Text.ElideRight
            text: bin.notice !== "" ? bin.notice : "I file restano recuperabili finché non svuoti il cestino."
            color: bin.notice !== "" ? "#e8a05f" : Theme.textFaint
            font.family: "DejaVu Sans"
            font.pixelSize: 9
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            component BinButton: Rectangle {
                id: action

                property string label: ""
                property bool enabledButton: true
                property bool danger: false
                signal clicked()

                width: Math.max(78, actionText.width + 22)
                height: 30
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

            BinButton {
                label: "Aggiorna"
                onClicked: trashModel.refresh()
            }

            BinButton {
                label: "Ripristina"
                enabledButton: bin.currentRow >= 0
                onClicked: restoreDialog.open("")
            }

            BinButton {
                label: "Elimina"
                danger: true
                enabledButton: bin.currentRow >= 0
                onClicked: purgeDialog.open("")
            }

            BinButton {
                label: "Svuota"
                danger: true
                enabledButton: trashModel.count > 0
                onClicked: emptyDialog.open("")
            }
        }
    }

    // --- conferme ------------------------------------------------------------
    Dialog2D {
        id: restoreDialog
        title: "RIPRISTINARE?"
        message: "L'elemento tornerà nella posizione originale."
        confirmLabel: "Ripristina"

        onAccepted: function () {
            close()
            if (trashModel.restore(bin.currentRow))
                bin.showNotice("Elemento ripristinato")
        }
        onCancelled: close()
    }

    Dialog2D {
        id: purgeDialog
        title: "ELIMINARE DEFINITIVAMENTE?"
        message: "L'operazione non è reversibile."
        confirmLabel: "Elimina"
        danger: true

        onAccepted: function () {
            close()
            if (trashModel.deleteForever(bin.currentRow))
                bin.showNotice("Elemento eliminato")
        }
        onCancelled: close()
    }

    Dialog2D {
        id: emptyDialog
        title: "SVUOTARE IL CESTINO?"
        message: "Tutti gli elementi verranno eliminati definitivamente. L'operazione non è reversibile."
        confirmLabel: "Svuota"
        danger: true

        onAccepted: function () {
            close()
            if (trashModel.empty())
                bin.showNotice("Cestino svuotato")
        }
        onCancelled: close()
    }
}
