#!/usr/bin/env bash

err() {
    >&2 echo "$@"
}

is_running() {
    systemctl is-active --quiet $ZOMBOID_UNIT
}
start() {
    systemctl start $ZOMBOID_UNIT || {
        err "failed to start server, exiting..."
        exit 1
    }
}
stop() {
    systemctl stop $ZOMBOID_UNIT || {
        err "failed to stop server, exiting..."
        exit 1
    }
}
restart() {
    systemctl restart $ZOMBOID_UNIT || {
        err "failed to restart server, exiting..."
        exit 1
    }
}

check_running() {
    if ! is_running; then
        echo "server not running..."
        read -rp "Start it? [y/n] " reply
        if [ "$reply" = y ]; then
            start
        else
            echo "exiting..."
            exit 0
        fi
    fi
}

if [ -z "$ZOMBOID_SOCKET" ]; then
    err "\$ZOMBOID_SOCKET is not set, exiting..."
    exit 1
fi
if [ -z "$ZOMBOID_UNIT" ]; then
    err "\$ZOMBOID_UNIT is not set, exiting..."
    exit 1
fi

subcommand=${1-}
shift 1 || true

case "$subcommand" in
    (start)
        if is_running; then
            echo "server already running, exiting..."
        else
            echo "starting server..."
            start
        fi
    ;;
    (stop)
        if is_running; then
            echo "stopping server..."
            stop
        else
            echo "server not running, exiting..."
        fi
    ;;
    (restart)
        echo "restarting server..."
        restart
    ;;
    (log)
        check_running
        journalctl --unit $ZOMBOID_UNIT --follow --output cat "$@"
    ;;
    (run)
        check_running
        if [ ${#@} -eq 0 ]; then
            echo "enter commands line by line:"
            socat READLINE OPEN:$ZOMBOID_SOCKET,wronly
        else
            echo "running command: '$*'"
            echo "$*" >$ZOMBOID_SOCKET
        fi
    ;;
    (*)
        >&2 echo "'$subcommand' is not a valid subcommand"
        exit 1
    ;;
esac
exit 0
