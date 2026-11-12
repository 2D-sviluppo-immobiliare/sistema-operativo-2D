import QtQuick

// Dialogo modale del desktop 2D.
//
// Un unico componente copre conferme, input di testo e avvisi: cosi' ogni
// operazione distruttiva passa dallo stesso punto e non ci sono finestre di
// sistema diverse dallo stile del desktop.
Item {
    id: dialog

    anchors.fill: parent
    visible: false
    z: 500
    focus: true

    property string title: ""
    property string message: ""
    property bool withInput: false
    property string inputText: ""
    property string placeholder: ""
    property string confirmLabel: "Conferma"
    property string cancelLabel: "Annulla"
    property bool danger: false

    signal accepted(string text)
    signal cancelled()

    function open(prefill) {
        inputText = prefill !== undefined ? prefill : ""
        visible = true
        dialog.forceActiveFocus()
        if (field)
            field.forceActiveFocus()
    }

    function close() {
        visible = false
    }

    // velo che blocca il resto dell'interfaccia
    Rectangle {
        anchors.fill: parent
        color: "#d003101c"

        MouseArea {
            anchors.fill: parent
            // assorbe i click: niente passa al contenuto sottostante
            onClicked: {}
        }
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.min(430, dialog.width - 60)
        height: contentColumn.implicitHeight + 48
        radius: 14
        color: "#0a1c2d"
        border.width: 1
        border.color: dialog.danger ? "#99b8443a" : "#55f9b234"

        Column {
            id: contentColumn

            x: 24
            y: 22
            width: parent.width - 48
            spacing: 12

            Text {
                width: parent.width
                text: dialog.title
                color: Theme.text
                font.family: "DejaVu Sans"
                font.pixelSize: 13
                font.bold: true
                font.letterSpacing: 1.4
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                visible: dialog.message !== ""
                text: dialog.message
                color: Theme.textDim
                font.family: "DejaVu Sans"
                font.pixelSize: 10
                lineHeight: 1.35
                wrapMode: Text.WordWrap
            }

            Rectangle {
                width: parent.width
                height: 36
                radius: 8
                visible: dialog.withInput
                color: "#05121e"
                border.width: 1
                border.color: field.activeFocus ? "#88f9b234" : "#18ffffff"

                TextInput {
                    id: field

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    selectionColor: "#556fbdbd"
                    selectedTextColor: "#031020"
                    font.family: "DejaVu Sans"
                    font.pixelSize: 12
                    text: dialog.inputText
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: dialog.placeholder
                        color: Theme.textFaint
                        font: field.font
                    }

                    onTextChanged: dialog.inputText = text
                    onAccepted: dialog.accepted(dialog.inputText)
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 10

                Rectangle {
                    width: 96
                    height: 34
                    radius: 8
                    color: cancelMouse.containsMouse ? "#16293a" : "#0d1c2a"
                    border.width: 1
                    border.color: "#18ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: dialog.cancelLabel
                        color: Theme.textDim
                        font.family: "DejaVu Sans"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            dialog.close()
                            dialog.cancelled()
                        }
                    }
                }

                Rectangle {
                    width: 124
                    height: 34
                    radius: 8
                    color: dialog.danger
                           ? (confirmMouse.containsMouse ? "#e8695f" : "#c0483f")
                           : (confirmMouse.containsMouse ? "#ffc85a" : "#f9b234")
                    border.width: 1
                    border.color: dialog.danger ? "#ff9a90" : "#ffe0a0"

                    Text {
                        anchors.centerIn: parent
                        text: dialog.confirmLabel
                        color: dialog.danger ? "#ffffff" : "#031020"
                        font.family: "DejaVu Sans"
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: dialog.accepted(dialog.inputText)
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: {
        dialog.close()
        dialog.cancelled()
    }
}
