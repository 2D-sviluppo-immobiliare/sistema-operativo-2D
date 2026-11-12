import QtQuick

// Icona di file o cartella, scelta in base alla tipologia rilevata dal backend.
Text {
    id: icon

    property string kind: "file"
    property int baseSize: 18

    font.family: "DejaVu Sans"
    font.pixelSize: baseSize
    font.bold: true
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    color: kind === "folder" ? "#f9b234"
         : kind === "image" ? "#6fbdbd"
         : kind === "video" ? "#a78bfa"
         : kind === "audio" ? "#4bc47a"
         : kind === "archive" ? "#d9a05b"
         : kind === "code" ? "#5aa9e6"
         : kind === "pdf" ? "#e8695f"
         : kind === "document" ? "#8fb8dd"
         : kind === "sheet" ? "#4bc47a"
         : kind === "presentation" ? "#e0b455"
         : kind === "executable" ? "#c9a0ff"
         : kind === "link" ? "#6fbdbd"
         : "#8fa9bd"

    text: kind === "folder" ? "\u25A4"
        : kind === "image" ? "\u25A3"
        : kind === "video" ? "\u25B6"
        : kind === "audio" ? "\u266B"
        : kind === "archive" ? "\u25A6"
        : kind === "code" ? "</>"
        : kind === "pdf" ? "\u25A4"
        : kind === "document" ? "\u25A4"
        : kind === "sheet" ? "\u25A6"
        : kind === "presentation" ? "\u25A4"
        : kind === "executable" ? "\u2699"
        : kind === "link" ? "\u2192"
        : "\u25A1"
}
