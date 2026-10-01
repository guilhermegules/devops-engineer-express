#!/usr/bin/env bash
# manage-telemetry.sh — lifecycle helper for the homework 15 ELK + collectd stack.
#
# Usage: ./manage-telemetry.sh {up|down|status|restart|logs|ps|clean|help}
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
ES_URL="${ES_URL:-http://localhost:9200}"
IMAGE_NAME="calculator-microservice:telemetry"

compose() {
    docker compose -f "${COMPOSE_FILE}" "$@"
}

startStack() {
    echo "Building the calculator image and starting Elasticsearch, Logstash, Kibana..."
    compose up -d --build
    waitForElasticsearch
    waitForLogstash
    echo
    statusStack
    echo
    echo "Kibana:  http://localhost:5601"
    echo "Metrics: curl 'http://localhost:9200/calculator-metrics-*/_count?q=metric.source:exec'"
    echo "Run ./send-requests.sh to generate traffic, then ./verify-telemetry.sh to confirm."
}

waitForElasticsearch() {
    local attempt
    for attempt in $(seq 1 60); do
        if curl -fsS "${ES_URL}/_cluster/health" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    echo "Elasticsearch did not become healthy at ${ES_URL}." >&2
    echo "Check ./manage-telemetry.sh logs elasticsearch" >&2
    return 1
}

# Elasticsearch reports healthy long before Logstash has booted its JVM and
# started the pipeline, and collectd discards the value lists it tries to ship
# while the listener is still down. Wait for the pipeline so that "up" returns
# only when collectd can actually deliver metrics.
waitForLogstash() {
    local attempt
    for attempt in $(seq 1 90); do
        if compose logs logstash 2>/dev/null | grep -q "Pipelines running"; then
            return 0
        fi
        sleep 2
    done
    echo "Logstash did not report a running pipeline." >&2
    echo "Check ./manage-telemetry.sh logs logstash" >&2
    return 1
}

stopStack() {
    echo "Stopping the stack (containers only, volumes are kept)..."
    compose down
}

statusStack() {
    compose ps
    echo
    if health="$(curl -fsS "${ES_URL}/_cluster/health" 2>/dev/null)"; then
        echo "Elasticsearch: ${health}"
    else
        echo "Elasticsearch: NOT RUNNING"
    fi
}

restartStack() {
    compose restart
    waitForElasticsearch
    waitForLogstash
}

showLogs() {
    compose logs --tail=100 -f "$@"
}

cleanStack() {
    echo "Removing containers, networks and volumes..."
    compose down -v --remove-orphans
    if docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
        echo "Removing image ${IMAGE_NAME}..."
        docker image rm "${IMAGE_NAME}" >/dev/null
    fi
    echo "Cleanup complete."
}

usage() {
    cat <<EOF
Usage: $(basename "$0") {up|down|status|restart|logs|ps|clean|help}

Commands:
  up        Build the calculator image and start the whole stack, then wait for
            Elasticsearch to report healthy and the Logstash pipeline to run
  down      Stop and remove the containers, keeping the volumes
  status    Show container state and the Elasticsearch cluster health
  restart   Restart the running containers
  logs      Follow the logs of every service, or of the ones given as arguments
            (e.g. ./$(basename "$0") logs calculator logstash)
  ps        Show the container state
  clean     Remove containers, networks, volumes and the built image
  help      Show this message

Environment:
  ES_URL    Elasticsearch base URL (default: ${ES_URL})
EOF
}

case "${1:-}" in
    up)      startStack ;;
    down)    stopStack ;;
    status)  statusStack ;;
    restart) restartStack ;;
    logs)    shift; showLogs "$@" ;;
    ps)      compose ps ;;
    clean)   cleanStack ;;
    help|-h|--help) usage ;;
    *)       usage; exit 1 ;;
esac
