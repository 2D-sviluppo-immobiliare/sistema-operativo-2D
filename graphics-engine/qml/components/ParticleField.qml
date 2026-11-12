import QtQuick

// Campo di particelle dorate: movimento lento e continuo.
// Su macchine senza accelerazione il numero scende (particles ridotto da Desktop).
Item {
    id: field

    property int count: 46
    property bool running: true

    Repeater {
        model: field.count

        Rectangle {
            id: mote

            property real seed: Math.random()
            property real speed: 6000 + seed * 9000

            width: 1.5 + seed * 3.0
            height: width
            radius: width / 2
            color: Theme.gold
            opacity: 0

            x: (seed * 1.618 % 1.0) * field.width
            y: field.height + 20

            NumberAnimation on y {
                running: field.running
                from: field.height + 20
                to: -30
                duration: mote.speed
                loops: Animation.Infinite
                easing.type: Easing.Linear
            }

            SequentialAnimation on opacity {
                running: field.running
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.10 + mote.seed * 0.40
                    duration: 1400 + mote.seed * 2600
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    to: 0.02
                    duration: 1400 + mote.seed * 2600
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }
}
