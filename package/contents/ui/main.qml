import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.taskmanager as TaskManager
import "views"

// Root applet: owns all state + logic (data sources, watcher lifecycle,
// window discovery). The actual UI lives in views/CompactView.qml and
// views/GameModePopup.qml, which receive state via properties and notify
// back through signals.
PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation

    // Count of registered GameMode clients, streamed from the watcher's data file.
    property int clientCount: 0
    // Non-empty when the last control action failed (e.g. gamemoded missing).
    property string lastError: ""

    // All currently active GameMode games (pid + name), as reported by the
    // watcher's authoritative stream. A persistent ListModel (QObject) passed by
    // reference to the popup; unlike a re-assigned JS array, row changes
    // propagate reliably to the view.
    ListModel {
        id: gamesModel
    }

    readonly property bool active: root.clientCount > 0
    // False when the watcher reports gamemoded is unreachable ("-1" marker).
    property bool gamemodeAvailable: true

    toolTipMainText: !root.gamemodeAvailable
        ? i18n("GameMode not available")
        : (root.active
            ? i18n("GameMode active (%1 clients)", root.clientCount)
            : i18n("GameMode inactive"))

    // Editor-agnostic path to the per-user runtime data file (must match
    // watcher.sh's BASE computation). It first waits for the file to exist:
    // `tail -F` launched before the file is created silently swallows appends,
    // so the widget would never see the active state. Watching from creation
    // guarantees every later transition is delivered.
    function dataFile() {
        return 'sh -c \'f="$XDG_RUNTIME_DIR/gamemode-status-$(id -u)/state.data"; ' +
            'n=0; while [ ! -e "$f" ] && [ $n -lt 100 ]; do sleep 0.05; n=$((n+1)); done; ' +
            'exec tail -n0 -F "$f" | { IFS= read -r line && echo "$line"; }\''
    }

    // ------------------------------------------------------------------
    // One-shot shell for control commands (register/unregister/probe).
    // Connected sources are disconnected after they complete so the same
    // command can run again.
    // ------------------------------------------------------------------
    Plasma5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        function run(script) {
            shell.connectSource(script)
        }
        onNewData: (source, data) => {
            shell.disconnectSource(source)
        }
    }

    // ------------------------------------------------------------------
    // Status reader, armed as exactly ONE blocking one-shot at a time:
    //   armCurrent() : tail -n1  -> snapshot of the current count, then
    //   armStream()  : tail -F -n0 | read -> waits for the next appended
    //                   count (0% CPU while idle), then exits and re-arms.
    // Because the watcher appends to a regular file that every instance
    // follows independently, N widgets all receive each event (multicast).
    // ------------------------------------------------------------------
    Plasma5Support.DataSource {
        id: status
        engine: "executable"

        function armCurrent() {
            // Snapshot the last (current) count; file may be empty on first
            // boot, in which case armStream below still picks up the boot line.
            Qt.callLater(function() {
                status.connectSource(
                    'sh -c \'tail -n1 "$XDG_RUNTIME_DIR/gamemode-status-$(id -u)/state.data" 2>/dev/null\'')
            })
        }

        function armStream() {
            // Defer to the next event-loop iteration so connecting from within
            // onNewData can't execute the new command synchronously and recurse
            // into onNewData again (RangeError).
            Qt.callLater(function() {
                status.connectSource(root.dataFile())
            })
        }

        onNewData: (source, data) => {
            // Line format: "<count>|<pid>:<name>;<pid>:<name>;..."
            const value = (data["stdout"] || "").trim()
            if (value === "") {
                status.disconnectSource(source)
                status.armStream()
                return
            }
            const parts = value.split("|")
            const n = parseInt(parts[0], 10)
            if (n === -1) {
                // Watcher's "service unavailable" marker (gamemoded not running).
                root.gamemodeAvailable = false
                root.clientCount = 0
                gamesModel.clear()
                status.disconnectSource(source)
                status.armStream()
                return
            }
            root.gamemodeAvailable = true
            if (!isNaN(n)) {
                root.clientCount = Math.max(0, n)
            }
            // Rebuild the game list from the authoritative stream. Games that
            // exited are already gone from the count, so this self-heals.
            gamesModel.clear()
            if (parts.length > 1) {
                const items = parts[1].split(";")
                for (let i = 0; i < items.length; ++i) {
                    const seg = items[i].split(":")
                    if (seg.length === 2 && seg[0] !== "") {
                        // Keep pid as a string: a JS number for large PIDs
                        // (e.g. 2521454) gets formatted as scientific notation
                        // ("2.52e+06") by i18n. A string displays verbatim.
                        gamesModel.append({ pid: seg[0], name: seg[1] })
                    }
                }
            }
            status.disconnectSource(source)
            // Always re-arm a streaming reader for the next event.
            status.armStream()
        }
    }

    // ------------------------------------------------------------------
    // Control with error feedback. Unlike the plain `shell`, this DataSource
    // inspects the command's exit code / stderr to surface failures (e.g.
    // gamemoded not running) instead of failing silently.
    // ------------------------------------------------------------------
    Plasma5Support.DataSource {
        id: control
        engine: "executable"
        function run(script) {
            control.connectSource(script)
        }
        onNewData: (source, data) => {
            const exit = data["exitcode"]
            if (exit && exit !== 0) {
                root.lastError = (data["stderr"] || "").trim() ||
                    i18n("GameMode is not available")
            } else {
                root.lastError = ""
            }
            control.disconnectSource(source)
        }
    }

    // Spawner for the long-lived watcher process. Launched raw via the shell engine
    // and detached with setsid+nohup so it survives this DataSource's lifetime and
    // fully detaches from plasmashell once the sh -c returns.
    function spawnWatcher() {
        const path = codePath("watcher.sh")
        shell.run("mkdir -p \"$XDG_RUNTIME_DIR/gamemode-status-$(id -u)\" && " +
            "setsid nohup bash \"" + path +
            "\" >> \"$XDG_RUNTIME_DIR/gamemode-status-$(id -u)/watcher.log\" 2>&1 &")
    }

    // Force a fresh watcher instance. Used by "Re-buscar servicio...": kills the
    // shared watcher (its start-up publish() re-checks availability), clears the
    // lock so a new one can spawn, and re-arms the reader to consume the fresh
    // state published right away. Affects all widgets at once (they share one
    // watcher + the same state.data), which is what we want.
    function restartWatcher() {
        const path = codePath("watcher.sh")
        shell.run('sh -c \'f="$XDG_RUNTIME_DIR/gamemode-status-$(id -u)/lock.d/pid"; ' +
            'p="$(cat "$f" 2>/dev/null)"; [ -n "$p" ] && kill -9 "$p" 2>/dev/null; ' +
            'sleep 0.3; rm -rf "$XDG_RUNTIME_DIR/gamemode-status-$(id -u)/lock.d"; ' +
            'mkdir -p "$XDG_RUNTIME_DIR/gamemode-status-$(id -u)"; ' +
            'setsid nohup bash "' + path + '" >> "$XDG_RUNTIME_DIR/gamemode-status-$(id -u)/watcher.log" 2>&1 &\'')
        // Re-read the (just published) current state once the new watcher is up.
        status.armCurrent()
    }

    // Idempotent bootstrap: ensure the watcher + reader are running. Wired to a
    // deferred root timer (KVitals pattern) and re-called from the compact view,
    // which is always constructed when the widget sits in the panel.
    property bool bootstrapped: false
    function bootstrap() {
        if (root.bootstrapped) {
            return
        }
        root.bootstrapped = true
        root.spawnWatcher()
        status.armCurrent()
    }

    // Defer bootstrap to the next event-loop iteration so every child DataSource
    // is fully instantiated before we call into it.
    Timer {
        id: rootTimer
        interval: 0
        repeat: false
        onTriggered: root.bootstrap()
    }

    Component.onCompleted: rootTimer.start()

    // ------------------------------------------------------------------
    // Window discovery (same public API the taskbar uses).
    // ------------------------------------------------------------------
    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByActivity: false
    }

    ListModel { id: windowList }

    // Refresh the window list as windows open/close while the popup is open.
    Connections {
        target: tasksModel
        function onCountChanged() {
            root.rebuildWindowList()
        }
    }

    function codePath(file) {
        // Contents/ui -> contents/code/<file>, then strip the file:// scheme so
        // it can be passed to the shell.
        return Qt.resolvedUrl("../code/" + file).toString().replace(/^file:\/\//, "")
    }

    function rebuildWindowList() {
        windowList.clear()
        let pending = []
        for (let i = 0; i < tasksModel.count; ++i) {
            const idx = tasksModel.index(i, 0)
            if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsWindow) !== true) {
                continue
            }
            if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsLauncher) === true) {
                continue
            }
            const pid = tasksModel.data(idx, TaskManager.AbstractTasksModel.AppPid)
            if (pid <= 0) {
                continue
            }
            let name = tasksModel.data(idx, TaskManager.AbstractTasksModel.AppName)
            if (name === "" || name === undefined || name === null) {
                // AppName empty (Wine/Proton) -> resolve from /proc later.
                name = "…"
                pending.push(pid)
            }
            windowList.append({ pid: pid, name: name })
        }
        if (pending.length > 0) {
            root.fillProcNames(pending)
        }
    }

    // Batch-resolve process names for a set of PIDs in one shell call, then
    // update the model in place. Avoiding per-pid async + clear() races: the
    // model was already populated with "…", we only fill gaps here.
    property bool namesPending: false
    Plasma5Support.DataSource {
        id: procNames
        engine: "executable"
        onNewData: (source, data) => {
            root.namesPending = false
            const out = (data["stdout"] || "").trim()
            if (out !== "") {
                for (const line of out.split("\n")) {
                    const idx = line.indexOf(":")
                    if (idx <= 0) continue
                    const pid = parseInt(line.substring(0, idx), 10)
                    const name = line.substring(idx + 1)
                    if (!isNaN(pid) && name !== "") {
                        for (let i = 0; i < windowList.count; ++i) {
                            if (windowList.get(i).pid === pid) {
                                windowList.setProperty(i, "name", name)
                                break
                            }
                        }
                    }
                }
            }
            procNames.disconnectSource(source)
        }
    }

    function fillProcNames(pids) {
        // Build one command echoing "pid:name" per line from /proc cmdlines.
        let cmds = []
        for (const pid of pids) {
            cmds.push('f="$(tr "\\0" " " < /proc/' + pid + '/cmdline 2>/dev/null)"; ' +
                'b="${f%% *}"; b="${b##*\\\\}"; [ -z "$b" ] && b="${b##*/}"; echo "' + pid + ':$b"')
        }
        if (root.namesPending) {
            return // a previous batch is still resolving; avoid stale feedback
        }
        procNames.connectSource(cmds.join("; "))
    }

    function startGame(pid) {
        control.run(codePath("control.sh") + " register " + pid)
    }

    function stopGame(pid) {
        control.run(codePath("control.sh") + " unregister " + pid)
    }

    // ------------------------------------------------------------------
    // Views: CompactView (panel) + GameModePopup (open popup). They receive
    // state via properties and report user actions back through signals.
    // ------------------------------------------------------------------
    compactRepresentation: CompactView {
        active: root.active
        gamemodeAvailable: root.gamemodeAvailable
        inactiveIconIndex: Plasmoid.configuration.inactiveIconIndex
        activeIconIndex: Plasmoid.configuration.activeIconIndex
        badgeColor: Plasmoid.configuration.badgeColor
        animationStyle: Plasmoid.configuration.animationStyle
        onActivated: root.expanded = !root.expanded
        // Ensure the watcher + reader are running (idempotent). The compact view
        // is the first thing constructed when the widget sits in the panel.
        Component.onCompleted: root.bootstrap()
    }

    fullRepresentation: GameModePopup {
        active: root.active
        gamemodeAvailable: root.gamemodeAvailable
        clientCount: root.clientCount
        games: gamesModel
        lastError: root.lastError
        windows: windowList
        onStartGame: (pid) => {
            root.startGame(pid)
            Plasmoid.expanded = false
        }
        onStopGame: (pid) => root.stopGame(pid)
        onOpenRequest: root.rebuildWindowList()
        onRequestRescan: root.restartWatcher()
    }
}