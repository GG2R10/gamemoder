import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Popup representation: shows current GameMode status, lets the user detach
// games this widget started, or start GameMode for any open window.
Item {
    id: popup

    implicitWidth: Kirigami.Units.gridUnit * 17
    implicitHeight: Kirigami.Units.gridUnit * 16

    // Set by main.qml (data + callbacks). games is a ListModel of {pid, name}.
    property bool active: false
    property bool gamemodeAvailable: true
    property int clientCount: 0
    property var games
    property string lastError: ""
    property var windows

    signal startGame(int pid)
    signal stopGame(int pid)
    signal openRequest()
    signal requestRescan()

    // fullRepresentation is (re)created each time the popup opens; ask main.qml
    // to refresh the window list so it always reflects the current windows.
    Component.onCompleted: popup.openRequest()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.gridUnit
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.weight: Font.Bold
            text: !popup.gamemodeAvailable ? i18n("GameMode not available")
                : (popup.active ? i18n("GameMode active") : i18n("Start GameMode for"))
        }

        // GameMode daemon not present/unreachable: full guidance instead of the
        // normal window/game controls.
        ColumnLayout {
            visible: !popup.gamemodeAvailable
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Kirigami.Theme.negativeTextColor
                text: i18n("GameMode service not detected.\n" +
                           "Install and start 'gamemoded' to use this widget.")
            }

            PlasmaComponents.Button {
                Layout.alignment: Qt.AlignHCenter
                text: i18n("Rescan service...")
                onClicked: popup.requestRescan()
            }
        }

        // Control failure feedback (gamemoded missing/unresponsive).
        PlasmaComponents.Label {
            visible: popup.lastError !== ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.negativeTextColor
            text: i18n("Error: %1", popup.lastError)
        }

        // Active: every GameMode client, each with a stop button.
        ListView {
            id: ownedList
            visible: popup.gamemodeAvailable && popup.active && popup.games.count > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: popup.games
            spacing: Kirigami.Units.smallSpacing
            clip: true

            delegate: RowLayout {
                width: ownedList.width
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Label {
                    text: i18n("%1 (PID %2)", model.name, model.pid)
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                PlasmaComponents.Button {
                    text: i18n("Stop")
                    onClicked: popup.stopGame(model.pid)
                }
            }
        }

        // Active but no game names resolved yet.
        PlasmaComponents.Label {
            visible: popup.gamemodeAvailable && popup.active && popup.games.count === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: i18n("GameMode is active.\nResolving clients…")
        }

        // Inactive: pick a window to optimize.
        PlasmaComponents.Label {
            visible: popup.gamemodeAvailable && !popup.active
            Layout.fillWidth: true
            text: i18n("Choose a window to optimize:")
            color: Kirigami.Theme.textColor
        }

        ListView {
            visible: popup.gamemodeAvailable && !popup.active
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: popup.windows
            spacing: Kirigami.Units.smallSpacing
            clip: true

            delegate: PlasmaComponents.Button {
                width: ListView.view.width
                text: model.name
                onClicked: popup.startGame(model.pid)
            }

            PlasmaComponents.Label {
                anchors.centerIn: parent
                visible: popup.windows ? popup.windows.count === 0 : false
                text: i18n("No windows open.")
            }
        }
    }
}