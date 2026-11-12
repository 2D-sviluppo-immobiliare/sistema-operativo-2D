pragma Singleton
import QtQuick

// 2D OS - costanti visive uniche del motore QML.
// Palette campionata dal desktop e dalla schermata di avvio di riferimento.
QtObject {
    // oro / ambra del marchio
    readonly property color gold:      "#f9b234"
    readonly property color goldLoad:  "#ebb951"
    readonly property color goldDim:   "#b9812a"
    readonly property color goldSoft:  "#d9b26a"

    // ciano del marchio
    readonly property color cyan:      "#6fbdbd"
    readonly property color cyanDim:   "#3d7f8c"

    // testo
    readonly property color text:      "#fafcfb"
    readonly property color textDim:   "#8fa9bd"
    readonly property color textFaint: "#5f7d94"

    // fondali
    readonly property color navy:      "#031020"
    readonly property color navyDeep:  "#000d1e"
    readonly property color navyBlue:  "#0a386d"
    readonly property color bootTop:   "#0d1e37"
    readonly property color bootMid:   "#102542"
    readonly property color bootLow:   "#081424"

    // superfici in vetro
    readonly property color glass:     "#0b1c2a"
    readonly property color glassHi:   "#16283a"
    readonly property color panel:     "#f2081726"
    readonly property color stroke:    "#2ef9b234"
    readonly property color strokeCyan: "#446fbdbd"

    // stato
    readonly property color green:     "#4bc47a"
    readonly property color greenDark: "#123c28"

    readonly property int radius:   16
    readonly property int iconSize: 44
    readonly property int margin:   28
}
