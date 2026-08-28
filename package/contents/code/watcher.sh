#!/usr/bin/env bash
#
# Persistent, event-driven watcher for GameMode.
#
# A single long-lived process listens on GameMode's D-Bus signals
# (GameRegistered / GameUnregistered) and, on every change, re-queries GameMode
# for the current ClientCount and the full game list (pid, executable), appending
# one status line to a shared, per-user data file.
#
# Status line format (one per event):
#   <count>|<pid>:<name>;<pid>:<name>;...
#   e.g. 2|1234:bash;5678:dolphin
#
# Every widget instance runs its own `tail -F -n0 | read` on that file, which
# blocks in the kernel (0% CPU) and wakes on each appended line. Because the
# watcher appends (never rewrites) and each reader follows the same file, a
# single event reliably reaches *all* instances (multicast), unlike a FIFO,
# which is point-to-point (a write reaches only one reader). Re-querying the
# authoritative value on each event (instead of a local counter) makes it
# robust to desync and missed signals.
#
set -u

# Base runtime dir, namespaced per-UID so the /tmp fallback (missing
# XDG_RUNTIME_DIR) can't collide across users or sessions.
BASE="${XDG_RUNTIME_DIR:-/tmp}/gamemode-status-$(id -u)"
mkdir -p -m 700 "$BASE"

DATA="$BASE/state.data"   # append-only status stream (one line per event)
LOCKDIR="$BASE/lock.d"    # directory-atomic single-instance guard
LOG="$BASE/watcher.log"
GD="/usr/bin/gdbus"
IFACE="com.feralinteractive.GameMode"

echo "boot base=$BASE pid=$$" >> "$LOG"

# --- Single-instance guard with stale-lock recovery -----------------------
# mkdir(2) is atomic, so concurrent spawns can't both win. The holder records
# its PID inside; if the lock survives but its process is gone (SIGKILL/crash
# skips the trap), it is declared stale and reclaimed instead of bricking the
# widget forever.
acquire_lock() {
    if mkdir "$LOCKDIR" 2>/dev/null; then
        echo $$ > "$LOCKDIR/pid"
        return 0
    fi
    local holder
    holder="$(cat "$LOCKDIR/pid" 2>/dev/null)"
    if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
        echo "already-running (pid=$holder), exiting" >> "$LOG"
        return 1
    fi
    echo "stale-lock holder='${holder}', recovering" >> "$LOG"
    rm -rf "$LOCKDIR"
    if mkdir "$LOCKDIR" 2>/dev/null; then
        echo $$ > "$LOCKDIR/pid"
        return 0
    fi
    return 1
}

if ! acquire_lock; then
    exit 0
fi

cleanup() {
    rm -rf "$LOCKDIR"
}
trap cleanup EXIT INT TERM

# Fresh, compact basis for the data stream (reset once per watcher lifetime).
: > "$DATA"

# Query the authoritative count straight from the service. Empty output when the
# service is missing/unreachable (gamemoded not running), which lets publish()
# emit a distinct "unavailable" marker instead of a bogus 0.
count() {
    local out
    out="$("$GD" call --session --dest com.feralinteractive.GameMode \
        --object-path /com/feralinteractive/GameMode \
        --method org.freedesktop.DBus.Properties.Get $IFACE ClientCount 2>/dev/null)"
    out="${out//[^0-9]/}"
    echo "$out"
}

# Resolve a human-readable name for a game PID, best-effort, in order:
#   1. GameMode's own Executable property (from its per-game D-Bus node), if it
#      is a real binary path (not a wrapper like /usr/bin/env).
#   2. The process's own comm from /proc (real executable, works for Proton/Wine
#      where the D-Bus Executable is a wine-preloader/wine64-preloader).
#   3. /proc/<pid>/exe basename as a last resort.
#   4. The pid itself if nothing is resolvable.
exec_name() {
    local pid="$1" exe name

    if [ -r "/proc/$pid/exe" ]; then
        name="$(basename "$(readlink "/proc/$pid/exe" 2>/dev/null)" 2>/dev/null)"
    fi

    exe="$("$GD" call --session --dest com.feralinteractive.GameMode \
        --object-path "/com/feralinteractive/GameMode/Games/$pid" \
        --method org.freedesktop.DBus.Properties.Get \
        "${IFACE}.Game" Executable 2>/dev/null)"
    exe="$(echo "$exe" | grep -oE "'[^']+'" | tr -d "'")"

    # Prefer a real absolute binary path; skip shell-ish/wine-ish wrappers.
    if [ -n "$exe" ] && [ "$exe" != "/usr/bin/env" ] && [ -n "${exe##*wine*}" ]; then
        echo "$(basename "$exe")"
        return 0
    fi

    # Fall back to /proc comm (the actual running executable name).
    if [ -n "$name" ] && [ "$name" != "wine-preloader" ] && [ "$name" != "wine64-preloader" ]; then
        echo "$name"
        return 0
    fi

    echo "$pid"
}

# Current game list as "pid:name;..." built from ListGames object paths.
game_list() {
    local out="$("$GD" call --session --dest com.feralinteractive.GameMode \
        --object-path /com/feralinteractive/GameMode \
        --method com.feralinteractive.GameMode.ListGames 2>/dev/null)"
    local pids result=""
    for pids in $(echo "$out" | grep -oE "Games/[0-9]+" | grep -oE "[0-9]+$"); do
        result="${result}${pids}:$(exec_name "$pids");"
    done
    echo "$result"
}

publish() {
    # Append (never rewrite) so every following reader catches the update.
    local c
    c="$(count)"
    if [ -z "$c" ]; then
        # gamemoded unreachable -> emit a distinct marker so the widget can
        # tell "0 games" apart from "service not available".
        echo "-1|" >> "$DATA"
    else
        echo "${c}|$(game_list)" >> "$DATA"
    fi
}

# Publish current state immediately (widget starts up-to-date).
publish

# Idle here = blocking read on the D-Bus socket = 0% CPU. Each GameRegistered/
# GameUnregistered signal re-publishes what GameMode says the state *is* now.
# There is no timer/polling: if the service comes back a game signal (or the
# widget's "Re-buscar servicio" reset) re-triggers publish().
"$GD" monitor --session \
    --dest com.feralinteractive.GameMode \
    --object-path /com/feralinteractive/GameMode |
while IFS= read -r line; do
    case "$line" in
        *GameRegistered*|*GameUnregistered*) publish ;;
    esac
done