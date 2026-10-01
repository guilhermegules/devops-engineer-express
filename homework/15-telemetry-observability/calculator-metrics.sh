#!/bin/sh
# calculator-metrics.sh - custom collectd metrics for the Go calculator microservice.
#
# The collectd exec plugin forks this script every <Interval> seconds and reads
# PUTVAL statements from STDOUT (see collectd-exec(5)). The metrics are derived
# from the calculator's own /calc/history endpoint, so they describe the
# microservice instead of the host it happens to run on.
#
# Usage: COLLECTD_HOSTNAME=calculator COLLECTD_INTERVAL=10 ./calculator-metrics.sh
set -u

HOST="${COLLECTD_HOSTNAME:-calculator}"
INTERVAL="${COLLECTD_INTERVAL:-10}"
HISTORY_URL="${HISTORY_URL:-http://127.0.0.1:8080/calc/history}"
HTTP_TIMEOUT="${HTTP_TIMEOUT:-3}"
OPERATIONS="sum sub mul div"

# PUTVAL identifier is host/plugin-plugin_instance/type-type_instance, so these
# land in Elasticsearch as plugin=exec, type=gauge, type_instance=<name>.
emit() {
    printf 'PUTVAL "%s/exec-calculator/gauge-%s" interval=%s N:%s\n' \
        "$HOST" "$1" "$INTERVAL" "$2"
}

count_occurrences() {
    printf '%s' "$HISTORY" | grep -o "$1" | wc -l | tr -d ' \n'
}

emit_zeroes() {
    emit operations_total 0
    for op in $OPERATIONS; do
        emit "operations_$op" 0
    done
    emit last_result 0
    emit history_bytes 0
}

# Reachability is about the HTTP call, not about there being anything to count: a
# freshly started service answers with the JSON literal "null" and is still healthy.
if HISTORY="$(curl -fsS --max-time "$HTTP_TIMEOUT" "$HISTORY_URL" 2>/dev/null)"; then
    emit app_reachable 1
else
    HISTORY=""
    emit app_reachable 0
fi

if [ -z "$HISTORY" ] || [ "$HISTORY" = "null" ]; then
    emit_zeroes
    exit 0
fi

emit operations_total "$(count_occurrences '"op":"[a-z]*"')"

for op in $OPERATIONS; do
    emit "operations_$op" "$(count_occurrences "\"op\":\"$op\"")"
done

LAST_RESULT="$(printf '%s' "$HISTORY" | grep -o '"result":[-0-9.eE+]*' | tail -n 1 | cut -d: -f2)"
[ -n "$LAST_RESULT" ] || LAST_RESULT=0
emit last_result "$LAST_RESULT"

emit history_bytes "$(printf '%s' "$HISTORY" | wc -c | tr -d ' \n')"
