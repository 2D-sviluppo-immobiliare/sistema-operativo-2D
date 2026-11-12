import QtQuick

// Calcolatrice 2D: applicazione nativa del desktop.
// Nessun programma esterno, nessun tema di sistema: si disegna con la stessa
// palette del resto dell'interfaccia e si chiude dal pulsante della finestra.
Item {
    id: calc

    width: 300
    height: 404
    focus: true

    property string expr: ""
    property string entry: "0"
    property real acc: 0
    property string pending: ""
    property bool fresh: true

    // --- logica --------------------------------------------------------------

    function symbol(op) {
        if (op === "*") return "\u00D7"
        if (op === "/") return "\u00F7"
        if (op === "-") return "\u2212"
        return "+"
    }

    function format(value) {
        if (!isFinite(value))
            return "ERRORE"
        var rounded = Math.round(value * 1e10) / 1e10
        var text = String(rounded)
        if (text.length > 14)
            text = rounded.toExponential(6)
        return text
    }

    function apply(a, b, op) {
        if (op === "+") return a + b
        if (op === "-") return a - b
        if (op === "*") return a * b
        if (op === "/") return b === 0 ? NaN : a / b
        return b
    }

    function digit(d) {
        if (fresh || entry === "0") {
            entry = d
            fresh = false
        } else if (entry.length < 14) {
            entry += d
        }
    }

    function dot() {
        if (fresh) {
            entry = "0."
            fresh = false
        } else if (entry.indexOf(".") === -1) {
            entry += "."
        }
    }

    function chooseOp(op) {
        var value = parseFloat(entry)
        if (pending !== "") {
            acc = apply(acc, value, pending)
            entry = format(acc)
        } else {
            acc = value
        }
        pending = op
        expr = format(acc) + "  " + symbol(op)
        fresh = true
    }

    function equals() {
        if (pending === "") {
            expr = ""
            fresh = true
            return
        }
        var value = parseFloat(entry)
        var result = apply(acc, value, pending)
        expr = format(acc) + "  " + symbol(pending) + "  " + format(value) + "  ="
        entry = format(result)
        acc = result
        pending = ""
        fresh = true
    }

    function clearAll() {
        entry = "0"
        acc = 0
        pending = ""
        expr = ""
        fresh = true
    }

    function backspace() {
        if (fresh)
            return
        entry = entry.length > 1 ? entry.slice(0, -1) : "0"
        if (entry === "-" || entry === "")
            entry = "0"
    }

    function negate() {
        if (entry === "0")
            return
        entry = entry.charAt(0) === "-" ? entry.slice(1) : "-" + entry
    }

    function percent() {
        entry = format(parseFloat(entry) / 100)
        fresh = true
    }

    readonly property var keys: [
        { label: "C",  kind: "clear",   tint: "#e8695f", op: "",  digit: "" },
        { label: "\u232B", kind: "back", tint: "#8fa9bd", op: "",  digit: "" },
        { label: "%",  kind: "percent", tint: "#8fa9bd", op: "",  digit: "" },
        { label: "\u00F7", kind: "op",  tint: "#f9b234", op: "/", digit: "" },

        { label: "7",  kind: "digit",   tint: "#fafcfb", op: "",  digit: "7" },
        { label: "8",  kind: "digit",   tint: "#fafcfb", op: "",  digit: "8" },
        { label: "9",  kind: "digit",   tint: "#fafcfb", op: "",  digit: "9" },
        { label: "\u00D7", kind: "op",  tint: "#f9b234", op: "*", digit: "" },

        { label: "4",  kind: "digit",   tint: "#fafcfb", op: "",  digit: "4" },
        { label: "5",  kind: "digit",   tint: "#fafcfb", op: "",  digit: "5" },
        { label: "6",  kind: "digit",   tint: "#fafcfb", op: "",  digit: "6" },
        { label: "\u2212", kind: "op",  tint: "#f9b234", op: "-", digit: "" },

        { label: "1",  kind: "digit",   tint: "#fafcfb", op: "",  digit: "1" },
        { label: "2",  kind: "digit",   tint: "#fafcfb", op: "",  digit: "2" },
        { label: "3",  kind: "digit",   tint: "#fafcfb", op: "",  digit: "3" },
        { label: "+",  kind: "op",      tint: "#f9b234", op: "+", digit: "" },

        { label: "\u00B1", kind: "negate", tint: "#8fa9bd", op: "", digit: "" },
        { label: "0",  kind: "digit",   tint: "#fafcfb", op: "",  digit: "0" },
        { label: ".",  kind: "dot",     tint: "#fafcfb", op: "",  digit: "" },
        { label: "=",  kind: "equals",  tint: "#031020", op: "",  digit: "" }
    ]

    // --- display -------------------------------------------------------------
    Rectangle {
        id: display

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        anchors.topMargin: 12
        height: 86
        radius: 10
        color: "#cc040e18"
        border.width: 1
        border.color: "#14ffffff"

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.top: parent.top
            anchors.topMargin: 12
            text: calc.expr === "" ? " " : calc.expr
            color: Theme.textFaint
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 11
        }

        Text {
            anchors.right: parent.right
            anchors.left: parent.left
            anchors.rightMargin: 16
            anchors.leftMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            horizontalAlignment: Text.AlignRight
            text: calc.entry
            color: calc.entry === "ERRORE" ? "#e8695f" : Theme.text
            font.family: "DejaVu Sans"
            font.pixelSize: calc.entry.length > 10 ? 22 : 30
            font.bold: true
            elide: Text.ElideLeft
        }
    }

    // --- tastiera ------------------------------------------------------------
    Grid {
        id: pad

        columns: 4
        rowSpacing: 8
        columnSpacing: 8
        width: 4 * 62 + 3 * 8
        height: 5 * 46 + 4 * 8
        x: (parent.width - width) / 2
        y: display.y + display.height + 12

        Repeater {
            model: calc.keys

            Rectangle {
                id: key

                required property var modelData
                required property int index

                readonly property bool isEquals: modelData.kind === "equals"

                width: 62
                height: 46
                radius: 10
                color: isEquals
                       ? (keyMouse.containsMouse ? "#ffc85a" : "#f9b234")
                       : (keyMouse.containsMouse ? "#f21b3348" : "#f212283a")
                border.width: 1
                border.color: isEquals
                              ? "#ffe0a0"
                              : (modelData.kind === "digit"
                                 ? "#16ffffff"
                                 : Qt.rgba(0.98, 0.70, 0.20, 0.20))

                Behavior on color { ColorAnimation { duration: 90 } }

                Text {
                    anchors.centerIn: parent
                    text: key.modelData.label
                    color: key.isEquals ? "#031020" : key.modelData.tint
                    font.family: "DejaVu Sans"
                    font.pixelSize: 16
                    font.bold: true
                }

                MouseArea {
                    id: keyMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        const k = key.modelData
                        if (k.kind === "digit")
                            calc.digit(k.digit)
                        else if (k.kind === "op")
                            calc.chooseOp(k.op)
                        else if (k.kind === "equals")
                            calc.equals()
                        else if (k.kind === "clear")
                            calc.clearAll()
                        else if (k.kind === "back")
                            calc.backspace()
                        else if (k.kind === "percent")
                            calc.percent()
                        else if (k.kind === "negate")
                            calc.negate()
                        else if (k.kind === "dot")
                            calc.dot()
                    }
                }
            }
        }
    }

    // --- tastiera fisica -----------------------------------------------------
    Keys.onPressed: function (event) {
        const t = event.text
        if (t.length === 1 && t >= "0" && t <= "9") {
            calc.digit(t)
            event.accepted = true
        } else if (t === "." || t === ",") {
            calc.dot()
            event.accepted = true
        } else if (t === "+" || t === "-" || t === "*" || t === "/") {
            calc.chooseOp(t)
            event.accepted = true
        } else if (t === "=" || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            calc.equals()
            event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
            calc.backspace()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            calc.clearAll()
            event.accepted = true
        }
    }
}
