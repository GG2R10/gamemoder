import QtQuick
import org.kde.kirigami as Kirigami
import "../anim" as Anim

// Compact panel representation: gamepad icon + status badge that makes it
// obvious at a glance whether GameMode is active (badge/outline) or idle. The
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
    // 0 = normal, 1 = large. Index order must match ConfigGeneral.qml.
    property int iconSize: 0
    readonly property real iconFraction: iconSize === 1 ? 0.8 : 0.7
    // 0 = breathing corner badge, 1 = outline around the icon. (Stored
    // values from the removed rotating-ring style, 1 or 2, map to the outline.)
    property int animationStyle: 0
    // See anim/AnimationController.qml: 0 = static (one short transition when
    // GameMode activates), 1 = continuous; fps index into
    // AnimationOptions.fpsValues.
    property int animationMode: 0
    property int animationFps: 2

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

    // Drives every active-state indicator below. Static by default; only
    // transforms (rotation/opacity/scale) are animated, never geometry - see
    // anim/README.md.
    Anim.AnimationController {
        id: anim
        active: compact.active && compact.gamemodeAvailable
        mode: compact.animationMode
        fpsIndex: compact.animationFps
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

    // Two-layer crossfade: the SVG has its own full-color art (multicolor
    // buttons, an all-green mando, etc.), so it's rendered as-is - no
    // isMask tint - and swapping source between the active/inactive icon
    // fades between layers instead of popping instantly.
    Item {
        id: iconCrossfade
        anchors.centerIn: parent
        width: compact.width * compact.iconFraction
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
            topMargin: compact.width * (compact.iconSize === 1 ? 0.06 : 0.14)
            rightMargin: compact.width * (compact.iconSize === 1 ? 0.02 : 0.10)
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

        // Transition: pop in from small. Continuous: breathe. At rest: 1.0.
        scale: anim.continuous ? 0.75 + 0.4 * anim.wave(1800)
                               : 0.6 + 0.4 * anim.easeOut(anim.transitionProgress)
    }

    // Border style: an outline that follows the icon's silhouette, in the
    // badge color (shaders/outline.frag dilates the icon's alpha). The icon
    // texture only re-renders when the icon changes, and the animation only
    // touches opacity/scale, so a static outline costs nothing.
    // Transition: fades in while settling from slightly larger. Continuous:
    // breathes 0.35..1.
    ShaderEffectSource {
        id: iconSource
        sourceItem: iconCrossfade
        live: true
        hideSource: false
        // Padding so the outline has room outside the icon's own bounds.
        readonly property real pad: Math.ceil(iconCrossfade.width * 0.12)
        sourceRect: Qt.rect(-pad, -pad, iconCrossfade.width + 2 * pad, iconCrossfade.height + 2 * pad)
        visible: false
    }
    ShaderEffect {
        id: borderIndicator
        z: -1
        x: iconCrossfade.x - iconSource.pad
        y: iconCrossfade.y - iconSource.pad
        width: iconCrossfade.width + 2 * iconSource.pad
        height: iconCrossfade.height + 2 * iconSource.pad
        visible: compact.gamemodeAvailable && compact.animationStyle >= 1 && compact.active

        property variant src: iconSource
        property color color: compact.badgeColor
        property size texel: Qt.size(1 / width, 1 / height)
        // ~6 % of the icon, at least 1.5 px.
        property real radius: Math.max(1.5, iconCrossfade.width * 0.06)
        fragmentShader: "../shaders/outline.frag.qsb"

        opacity: anim.continuous ? 0.35 + 0.65 * anim.wave(2000)
                                 : anim.easeOut(anim.transitionProgress)
        scale: (anim.continuous ? 1.0 : 1.25 - 0.25 * anim.easeOut(anim.transitionProgress)) * iconCrossfade.scale
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
