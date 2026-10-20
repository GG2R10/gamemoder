import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../anim" as Anim

Kirigami.FormLayout {
    id: page

    // See micdroid's ConfigAudio.qml for why this plain `title` property
    // is needed (KCM page title binding quirk).
    property string title: i18n("General")

    // Index order must match CompactView.qml's iconFiles.
    readonly property var iconFiles: [
        "gamemoder.svg",
        "gamemoder-green.svg",
        "gamemoder-full-green.svg",
        "gamemoder-black.svg"
    ]
    readonly property var iconLabels: [
        i18n("Multicolor (default)"),
        i18n("Green buttons"),
        i18n("Fully green"),
        i18n("Off (black)")
    ]

    property alias cfg_inactiveIconIndex: inactiveIconCombo.currentIndex
    property alias cfg_activeIconIndex: activeIconCombo.currentIndex
    property alias cfg_badgeColor: badgeColorHolder.color
    // Plain property (not an alias): stored values >= 1 from the removed
    // rotating-ring style must still select a valid combo entry.
    property int cfg_animationStyle: 0
    property alias cfg_hoverStyle: hoverCombo.currentIndex
    readonly property int cfg_hoverStyleDefault: 0
    property alias cfg_iconSize: sizeCombo.currentIndex
    readonly property int cfg_iconSizeDefault: 0
    property alias cfg_animationMode: modeCombo.currentIndex
    property alias cfg_animationFps: fpsCombo.currentIndex
    readonly property int cfg_animationModeDefault: 0
    readonly property int cfg_animationFpsDefault: 2
    readonly property int cfg_inactiveIconIndexDefault: 3
    readonly property int cfg_activeIconIndexDefault: 0
    readonly property color cfg_badgeColorDefault: "#0eff16"
    readonly property int cfg_animationStyleDefault: 0

    // Holds the alias target for the Color-typed kcfg entry - a plain
    // `property color` has nothing on its own to bind to.
    Item {
        id: badgeColorHolder
        property color color: "#0eff16"
        visible: false
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Icon while idle:")
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            source: Qt.resolvedUrl("../../icons/" + page.iconFiles[inactiveIconCombo.currentIndex])
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
        }
        QQC2.ComboBox {
            id: inactiveIconCombo
            model: page.iconLabels
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Icon while active:")
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            source: Qt.resolvedUrl("../../icons/" + page.iconFiles[activeIconCombo.currentIndex])
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
        }
        QQC2.ComboBox {
            id: activeIconCombo
            model: page.iconLabels
        }
    }

    QQC2.ComboBox {
        id: hoverCombo
        Kirigami.FormData.label: i18n("Hover animation:")
        model: Anim.AnimationOptions.hoverStyleLabels
    }

    QQC2.ComboBox {
        id: sizeCombo
        Kirigami.FormData.label: i18n("Icon size:")
        // Index order must match CompactView.qml's iconFraction.
        model: [i18n("Normal"), i18n("Large")]
    }
    QQC2.Label {
        Kirigami.FormData.isSection: true
        text: i18n("The controller art is wide and short, so it can look smaller than square icons next to it in the panel. Large fills more of the panel slot.")
        wrapMode: Text.WordWrap
        font.italic: true
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 25
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true }

    RowLayout {
        Kirigami.FormData.label: i18n("Badge color:")
        spacing: Kirigami.Units.smallSpacing
        Rectangle {
            width: Kirigami.Units.iconSizes.small
            height: width
            radius: width / 2
            color: badgeColorHolder.color
            border.width: 1
            border.color: Kirigami.Theme.textColor
        }
        QQC2.Button {
            text: i18n("Choose…")
            onClicked: colorDialog.open()
        }
    }
    QQC2.Label {
        Kirigami.FormData.isSection: true
        text: i18n("Used for the status badge and, with the outline style below, the outline itself.")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 25
        font.italic: true
    }

    ColorDialog {
        id: colorDialog
        selectedColor: badgeColorHolder.color
        onAccepted: badgeColorHolder.color = selectedColor
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true }

    QQC2.ComboBox {
        id: animationCombo
        Kirigami.FormData.label: i18n("Active-state animation:")
        // Index order must match CompactView.qml's animationStyle.
        model: [
            i18n("Breathing badge"),
            i18n("Icon outline")
        ]
        currentIndex: Math.min(page.cfg_animationStyle, 1)
        onActivated: page.cfg_animationStyle = currentIndex
    }

    QQC2.ComboBox {
        id: modeCombo
        Kirigami.FormData.label: i18n("Animation:")
        model: Anim.AnimationOptions.modeLabels
    }

    QQC2.ComboBox {
        id: fpsCombo
        Kirigami.FormData.label: i18n("Frame rate:")
        enabled: modeCombo.currentIndex === 1
        model: Anim.AnimationOptions.fpsLabels
    }

    QQC2.Label {
        Kirigami.FormData.isSection: true
        text: i18n("Static mode plays one short animation when GameMode activates, then stays still and costs nothing. Continuous mode keeps animating; every frame repaints the whole panel (and its blur), so keep the frame rate low. Animations are disabled automatically when Plasma's animation speed is set to instant.")
        wrapMode: Text.WordWrap
        font.italic: true
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 25
    }
}
