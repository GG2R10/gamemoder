import QtQuick
import org.kde.kirigami as Kirigami

// Compact panel representation: gamepad icon + status badge that makes it
// obvious at a glance whether GameMode is active (green) or idle (dimmed).
Item {
    id: compact

    implicitWidth: Kirigami.Units.gridUnit * 1.8
    implicitHeight: Kirigami.Units.gridUnit * 1.8

    // Set by main.qml.
    property bool active: false
    property bool gamemodeAvailable: true

    // Local hover / press + deferred-theme state.
    property bool hovered: false
    property bool pressed: false
    // Defer isMask+color until after Plasma's theme startup (KVitals pattern)
    // to avoid touching color before the platform theme is initialized.
    property bool themeReady: false

    // Emitted when the user clicks the icon.
    signal activated()

    Timer {
        interval: 0
        repeat: false
        running: true
        onTriggered: compact.themeReady = true
    }

    // "Pill" background — the same visual language as the system tray. It lives
    // behind the icon, so it doesn't compete with (or scale) the icon glyph.
    Rectangle {
        id: hoverBg
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 0.5
        radius: Kirigami.Units.cornerRadius ?? 4
        color: Kirigami.Theme.highlightColor
        opacity: compact.hovered ? (compact.pressed ? 0.28 : 0.16) : 0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    Kirigami.Icon {
        id: gamepadIcon
        anchors.centerIn: parent
        source: "applications-games"
        fallback: "input-gaming"
        isMask: compact.themeReady
        // Greyed out and dimmed when the GameMode daemon is unreachable.
        color: compact.themeReady
            ? (!compact.gamemodeAvailable ? "#777777"
                : (compact.active ? "#45d95c" : (compact.hovered ? "#cfcfcf" : "#ffffff")))
            : Qt.rgba(0, 0, 0, 0)
        width: compact.width * 0.7
        height: width
        opacity: compact.active ? 1.0 : (compact.gamemodeAvailable ? 1.0 : 0.4)

        // The icon scales independently of the tile: a light "pop" on hover, a
        // slight "squish" on press. OutBack adds a little bounce so it feels
        // weighted instead of just "bigger".
        scale: compact.pressed ? 0.90 : (compact.hovered ? 1.12 : 1.0)
        transformOrigin: Item.Center

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale {
            NumberAnimation {
                duration: compact.pressed ? 80 : 220
                easing.type: Easing.OutBack
                easing.overshoot: 1.8
            }
        }
    }

    // Clear status badge: green when GameMode is active, hidden when idle.
    Rectangle {
        id: statusDot
        anchors {
            top: compact.top
            right: compact.right
            topMargin: compact.width * 0.14
            rightMargin: compact.width * 0.10
        }
        width: compact.width * 0.22
        height: width
        radius: width / 2
        color: compact.active ? "#0eff16" : "#7f7f7f"
        border {
            width: Math.max(1, Math.round(compact.width * 0.02))
            color: Kirigami.Theme.backgroundColor
        }
        visible: compact.gamemodeAvailable && (compact.themeReady || compact.active)
        opacity: compact.active ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Subtle breathing only when active — reinforces "this is running right
        // now" without being a blinking alarm.
        SequentialAnimation on scale {
            running: compact.active && compact.gamemodeAvailable
            loops: Animation.Infinite
            NumberAnimation { from: 0.75; to: 1.15; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.15; to: 0.75; duration: 900; easing.type: Easing.InOutSine }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: compact.hovered = true
        onExited: compact.hovered = false
        onPressed: compact.pressed = true
        onReleased: compact.pressed = false
        onCanceled: compact.pressed = false
        onClicked: compact.activated()
    }
}