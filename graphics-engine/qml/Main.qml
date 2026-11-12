import QtQuick
import QtQuick.Window
import "components"

// 2D OS - finestra principale del desktop proprietario (motore QML).
//
// Avvio:
//   Main.qml               desktop diretto
//   Main.qml --boot        sequenza di avvio, poi desktop
//
Window {
    id: root

    objectName: "TwoDMainWindow"
    title: "2D OS"

    // Finestra normale: nessun flag che la renda trasparente agli input.
    flags: Qt.Window

    property bool runBoot: typeof startWithBoot !== "undefined" ? startWithBoot : false
    property bool bootFinished: !runBoot

    visible: true
    width: 1280
    height: 800
    color: Theme.navyDeep

    Component.onCompleted: console.log("[2D] finestra creata (boot:", runBoot, ")")

    // Superficie di input del desktop: figlia diretta della Window.
    MouseArea {
        id: desktopInput

        anchors.fill: parent
        z: 1
        enabled: true
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) { console.log("[2D DESKTOP] CLICKED", mouse.x, mouse.y) }
    }

    Item {
        id: desktopLayer

        anchors.fill: parent
        z: 2
        enabled: true
        focus: true

        // Alt+Tab cambia finestra in primo piano. Senza un window manager
        // esterno la combinazione arriva direttamente alla shell.
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Tab && (event.modifiers & Qt.AltModifier)) {
                event.accepted = true
                desktopView.cycleWindow()
            }
        }

        Desktop {
            id: desktopView
            objectName: "Desktop"
            anchors.fill: parent
            visible: root.bootFinished
            opacity: root.bootFinished ? 1 : 0
            scale: root.bootFinished ? 1 : 1.04

            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
        }

        BootExperience {
            id: bootLayer

            anchors.fill: parent
            visible: root.runBoot

            onFinished: {
                console.log("[2D] boot completato")
                root.bootFinished = true
                bootLayer.visible = false
            }
        }
    }
}
