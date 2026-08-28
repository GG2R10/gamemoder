#!/usr/bin/env bash
#
# Control GameMode over D-Bus. Used by the widget to start/stop a game by PID,
# without going through the gamemoded CLI or wrapping gamemoderun.
#
# Exits non-zero (and prints a message to stderr) when the call fails, e.g. the
# gamemoded service is not running, so the widget can surface the error instead
# of failing silently.
#
# usage: control.sh register|unregister <pid>
set -u

DEST="--dest com.feralinteractive.GameMode"
OBJECT="--object-path /com/feralinteractive/GameMode"

case "${1:-}" in
    register)
        /usr/bin/gdbus call --session \
            $DEST $OBJECT \
            --method com.feralinteractive.GameMode.RegisterGame "$2" \
            || { echo "register failed: is gamemoded running?" >&2; exit 1; }
        ;;
    unregister)
        /usr/bin/gdbus call --session \
            $DEST $OBJECT \
            --method com.feralinteractive.GameMode.UnregisterGame "$2" \
            || { echo "unregister failed: is gamemoded running?" >&2; exit 1; }
        ;;
    *)
        echo "usage: $0 register|unregister <pid>" >&2
        exit 1
        ;;
esac