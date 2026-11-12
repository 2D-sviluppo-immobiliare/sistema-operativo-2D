import QtQuick

// Blocco note dell'ambiente 2D: testo libero, salvato solo in memoria.
Item {
    id: notes

    Rectangle {
        anchors.fill: parent
        color: "#99050f1a"
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 16
        visible: editor.text === ""
        text: "Scrivi qui le tue note..."
        color: Theme.textFaint
        font.family: "DejaVu Sans Mono"
        font.pixelSize: 12
    }

    TextEdit {
        id: editor

        anchors.fill: parent
        anchors.margins: 14
        color: Theme.text
        selectionColor: "#666fbdbd"
        selectedTextColor: "#031020"
        font.family: "DejaVu Sans Mono"
        font.pixelSize: 12
        wrapMode: TextEdit.Wrap
        selectByMouse: true
        persistentSelection: true
        cursorVisible: true
        focus: true
    }
}
