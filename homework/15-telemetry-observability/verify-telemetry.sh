#!/usr/bin/env bash
# verify-telemetry.sh — prove that the collectd metrics and the logs made it into
# Elasticsearch.
#
# Usage: ./verify-telemetry.sh
set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
APP_URL="${APP_URL:-http://localhost:8080}"
FAILURES=0

pass() {
    echo "OK:   $1"
}

fail() {
    echo "FAIL: $1"
    FAILURES=$((FAILURES + 1))
}

info() {
    echo "--   $1"
}

# Echo the document count of an index pattern, or "missing" if it does not exist.
doc_count() {
    local pattern="$1" response
    if ! response="$(curl -fsS -G "${ES_URL}/${pattern}/_count" 2>/dev/null)"; then
        echo "missing"
        return
    fi
    echo "$response" | grep -o '"count":[0-9]*' | head -1 | cut -d: -f2
}

query_count() {
    local pattern="$1" query="$2" response
    if ! response="$(curl -fsS -G "${ES_URL}/${pattern}/_count" --data-urlencode "q=${query}" 2>/dev/null)"; then
        echo "missing"
        return
    fi
    echo "$response" | grep -o '"count":[0-9]*' | head -1 | cut -d: -f2
}

echo "== Elasticsearch =="
if health="$(curl -fsS "${ES_URL}/_cluster/health" 2>/dev/null)"; then
    pass "Elasticsearch is up (${ES_URL})"
    info "cluster health: ${health}"
else
    fail "Elasticsearch is not reachable at ${ES_URL} - run ./manage-telemetry.sh up"
    echo
    echo "Cannot check indices without Elasticsearch. Aborting."
    exit 1
fi

echo
echo "== Microservice =="
if result="$(curl -fsS --max-time 5 "${APP_URL}/calc/sum/2/3" 2>/dev/null)"; then
    pass "calculator answered /calc/sum/2/3"
    info "${result}"
else
    fail "calculator is not reachable at ${APP_URL} - run ./manage-telemetry.sh up"
fi

echo
echo "== Indices =="
for pattern in calculator-metrics-* calculator-app-logs-* calculator-collectd-logs-*; do
    count="$(doc_count "${pattern}")"
    if [ "${count}" = "missing" ]; then
        fail "${pattern} does not exist yet (no documents indexed)"
    elif [ "${count}" -gt 0 ] 2>/dev/null; then
        pass "${pattern} has ${count} document(s)"
    else
        fail "${pattern} exists but is still empty"
    fi
done

echo
echo "== Custom collectd metrics =="
custom="$(query_count "calculator-metrics-*" "metric.source:exec")"
if [ "${custom}" = "missing" ]; then
    fail "calculator-metrics-* does not exist yet - collectd has not reported anything"
    info "check ./manage-telemetry.sh logs calculator for collectd/write_http errors"
elif [ "${custom}" -gt 0 ] 2>/dev/null; then
    pass "custom metrics from the exec plugin reached Elasticsearch (${custom} value lists)"
else
    fail "no custom exec metrics indexed yet - wait one collectd interval (10s) and retry"
fi

reachable="$(query_count "calculator-metrics-*" "metric.name:exec.calculator.gauge.app_reachable")"
if [ "${reachable}" != "missing" ] && [ "${reachable}" -gt 0 ] 2>/dev/null; then
    pass "app_reachable gauge is being reported (${reachable} value lists)"
else
    fail "app_reachable gauge is missing - the exec script is not running"
fi

echo
echo "== Host metrics =="
for source in cpu memory load uptime; do
    count="$(query_count "calculator-metrics-*" "metric.source:${source}")"
    if [ "${count}" != "missing" ] && [ "${count}" -gt 0 ] 2>/dev/null; then
        pass "collectd is reporting ${source} metrics (${count} value lists)"
    else
        fail "no ${source} metrics indexed"
    fi
done

# The collectd interface plugin is configured to skip loopback, so eth0 should
# be present and lo should not be.
eth0="$(query_count "calculator-metrics-*" "plugin_instance:eth0 AND metric.source:interface")"
lo="$(query_count "calculator-metrics-*" "plugin_instance:lo AND metric.source:interface")"
if [ "${eth0}" != "missing" ] && [ "${eth0}" -gt 0 ] 2>/dev/null; then
    pass "interface metrics are reported for eth0 (${eth0} value lists)"
else
    fail "no interface metrics for eth0 - check the interface plugin block"
fi
if [ "${lo}" = "0" ]; then
    pass "loopback (lo) is correctly excluded from the interface metrics"
else
    fail "loopback (lo) is being reported - add IgnoreSelected true to the interface block"
fi

echo
echo "== Pipeline health =="
bad="$(query_count "calculator-metrics-*" "_rubyexception OR _jsonparsefailure")"
if [ "${bad}" = "0" ]; then
    pass "no ruby or json parse failures in the indexed metrics"
else
    fail "${bad} metric document(s) carry a _rubyexception or _jsonparsefailure tag"
    info "check ./manage-telemetry.sh logs logstash"
fi

echo
echo "== Sample custom metric =="
curl -fsS -G "${ES_URL}/calculator-metrics-*/_search" \
    --data-urlencode "q=metric.source:exec" \
    --data-urlencode "size=1" \
    --data-urlencode "sort=@timestamp:desc" \
    --data-urlencode "_source=metric,@timestamp" \
    --data-urlencode "pretty=true" 2>/dev/null || echo "(no sample available)"

echo
echo "== Kibana =="
info "http://localhost:5601 - create a data view for calculator-metrics-* to chart the series"

echo
if [ "${FAILURES}" -eq 0 ]; then
    echo "All checks passed."
    exit 0
fi

echo "${FAILURES} check(s) failed."
exit 1
