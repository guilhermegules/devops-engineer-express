#!/bin/sh
# entrypoint.sh - run the calculator microservice and collectd side by side.
#
# collectd samples the microservice every 10s and ships the values to Logstash
# (and therefore Elasticsearch), while the microservice's own stdout/stderr is
# appended to a file that Logstash tails. The two log files live on a volume
# shared with the logstash container.
set -u

LOG_DIR="${LOG_DIR:-/var/log/calculator}"
LOGSTASH_URL="${LOGSTASH_URL:-http://logstash:8080/}"
APP_LOG="${LOG_DIR}/calculator.log"
COLLECTD_LOG="${LOG_DIR}/collectd-logs.json"

mkdir -p "$LOG_DIR"
# Only create the files if they are missing. Truncating them here would drop the
# logs of the previous run and leave the Logstash file inputs with a sincedb
# position that points past the end of the new file, so they would skip
# whatever is written next. Use ./manage-telemetry.sh down -v to start over.
touch "$APP_LOG" "$COLLECTD_LOG"

APP_PID=""
COLLECTD_PID=""

shutdown() {
    echo "entrypoint: shutting down"
    [ -n "$COLLECTD_PID" ] && kill "$COLLECTD_PID" 2>/dev/null
    [ -n "$APP_PID" ] && kill "$APP_PID" 2>/dev/null
    wait 2>/dev/null
    return 0
}
trap shutdown TERM INT

echo "entrypoint: calculator microservice on :8080"
echo "entrypoint: collectd shipping metrics to ${LOGSTASH_URL}"
echo "entrypoint: app log ${APP_LOG}"
echo "entrypoint: collectd log ${COLLECTD_LOG}"

./calculator >>"$APP_LOG" 2>&1 &
APP_PID=$!

/usr/sbin/collectd -f -C /etc/collectd.conf &
COLLECTD_PID=$!

# Container lifetime follows both processes: if either exits, wind the other one
# down so docker (and compose) can restart the pair.
while kill -0 "$APP_PID" 2>/dev/null && kill -0 "$COLLECTD_PID" 2>/dev/null; do
    sleep 2
done

shutdown
