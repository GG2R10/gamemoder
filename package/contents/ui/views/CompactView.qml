import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// Compact panel representation: gamepad icon + status badge that makes it
// obvious at a glance whether GameMode is active (badge/ring) or idle. The
// icon itself never recolors on its own - which icon file is shown per
// state, the badge color, and the active-state animation are all user
// picks (see ConfigGeneral.qml), forwarded here from main.qml.
Item {
    id: compact

    implicitWidth: Kirigami.Units.gridUnit * 1.8
    implicitHeight: Kirigami.Units.gridUnit * 1.8

    // Set by main.qml.
    property bool active: false
    property bool gamemodeAvailable: true
    property int inactiveIconIndex: 3
    property int activeIconIndex: 0
    property color badgeColor: "#0eff16"
    // 0 = breathing corner badge, 1 = rotating ring around the icon.
    property int animationStyle: 0

    // Index order must match ConfigGeneral.qml's iconFiles/iconLabels.
    readonly property var iconFiles: [
        "gamemoder.svg",
        "gamemoder-green.svg",
        "gamemoder-full-green.svg",
        "gamemoder-black.svg"
    ]
    readonly property string iconPath: Qt.resolvedUrl("../../icons/" +
        compact.iconFiles[compact.active ? compact.activeIconIndex : compact.inactiveIconIndex])

    // Local hover / press state.
    property bool hovered: false
    property bool pressed: false

    // Emitted when the user clicks the icon.
    signal activated()

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

    // Two-layer crossfade: the SVG has its own full-color art (multicolor
    // buttons, an all-green mando, etc.), so it's rendered as-is - no
    // isMask tint - and swapping source between the active/inactive icon
    // fades between layers instead of popping instantly.
    Item {
        id: iconCrossfade
        anchors.centerIn: parent
        width: compact.width * 0.7
        height: width
        opacity: compact.gamemodeAvailable ? 1.0 : 0.4
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // The icon scales independently of the tile: a light "pop" on hover, a
        // slight "squish" on press. OutBack adds a little bounce so it feels
        // weighted instead of just "bigger".
        scale: compact.pressed ? 0.90 : (compact.hovered ? 1.12 : 1.0)
        transformOrigin: Item.Center
        Behavior on scale {
            NumberAnimation {
                duration: compact.pressed ? 80 : 220
                easing.type: Easing.OutBack
                easing.overshoot: 1.8
            }
        }

        property bool showA: true

        Kirigami.Icon {
            id: iconA
            anchors.fill: parent
            isMask: false
            opacity: iconCrossfade.showA ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Component.onCompleted: source = compact.iconPath
        }
        Kirigami.Icon {
            id: iconB
            anchors.fill: parent
            isMask: false
            opacity: iconCrossfade.showA ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
    }

    onIconPathChanged: {
        // Load the new icon into the currently-hidden layer, then flip which
        // layer is on top - both Behaviors above fire together, giving a
        // true crossfade instead of a blink-through-transparent swap.
        if (iconCrossfade.showA) {
            iconB.source = compact.iconPath
        } else {
            iconA.source = compact.iconPath
        }
        iconCrossfade.showA = !iconCrossfade.showA
    }

    // Clear status badge: visible when GameMode is active, hidden when idle.
    // Only shown in the "breathing badge" animation style - the rotating
    // ring below is its own self-sufficient active indicator.
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
        color: compact.active ? compact.badgeColor : "#7f7f7f"
        border {
            width: Math.max(1, Math.round(compact.width * 0.02))
            color: Kirigami.Theme.backgroundColor
        }
        visible: compact.gamemodeAvailable && compact.animationStyle === 0
        opacity: compact.active ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Subtle breathing only when active — reinforces "this is running right
        // now" without being a blinking alarm.
        SequentialAnimation on scale {
            running: compact.active && compact.gamemodeAvailable && compact.animationStyle === 0
            loops: Animation.Infinite
            NumberAnimation { from: 0.75; to: 1.15; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.15; to: 0.75; duration: 900; easing.type: Easing.InOutSine }
        }
    }

    // Rotating ring around the icon — alternative active indicator, a single
    // short arc sweeping continuously. Cheap: one small GPU-rendered Shape,
    // only instantiated/animated while this style is selected and active.
    Item {
        id: ringIndicator
        anchors.fill: iconCrossfade
        visible: compact.gamemodeAvailable && compact.animationStyle === 1 && compact.active

        property real sweepStart: 0
        NumberAnimation on sweepStart {
            running: ringIndicator.visible
            from: 0
            to: 360
            duration: 2200
            loops: Animation.Infinite
        }

        Shape {
            anchors.fill: parent
            antialiasing: true
            ShapePath {
                strokeColor: compact.badgeColor
                strokeWidth: Math.max(1.5, ringIndicator.width * 0.05)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ringIndicator.width / 2
                    centerY: ringIndicator.height / 2
                    radiusX: ringIndicator.width / 2 - ringIndicator.width * 0.06
                    radiusY: ringIndicator.height / 2 - ringIndicator.height * 0.06
                    startAngle: ringIndicator.sweepStart
                    sweepAngle: 100
                }
            }
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
