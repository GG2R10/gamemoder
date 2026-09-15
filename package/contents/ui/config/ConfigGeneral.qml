import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

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
    property alias cfg_animationStyle: animationCombo.currentIndex
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
        text: i18n("Used for the status badge and, with the rotating-ring style below, the ring itself.")
        wrapMode: Text.WordWrap
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
            i18n("Rotating ring")
        ]
    }
}
