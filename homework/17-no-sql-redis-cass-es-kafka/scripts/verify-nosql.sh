#!/usr/bin/env bash
#
# verify-nosql.sh
# ---------------
# Uses Ansible (ad-hoc shell commands) to confirm that all four datastores
# provisioned by the [nosql] group are actually answering.
#
# Usage:
#   ./scripts/verify-nosql.sh [inventory] [group]
#
# Defaults:
#   inventory = inventory/hosts.ini
#   group     = nosql
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

INVENTORY="${1:-${PROJECT_DIR}/inventory/hosts.ini}"
GROUP="${2:-${GROUP:-nosql}}"

ANSIBLE_BIN="${ANSIBLE_BIN:-ansible}"

run() {
  "${ANSIBLE_BIN}" "${GROUP}" -i "${INVENTORY}" -b -m shell -a "$1"
}

echo "==> Redis: PING"
run "redis-cli ping | grep -q PONG && echo 'Redis OK'"

echo "==> Elasticsearch: cluster health"
run "curl -fsS 'http://127.0.0.1:9200/_cluster/health' && echo 'Elasticsearch OK'"

echo "==> Cassandra: native transport listening on 9042"
run "ss -ltn | grep -q ':9042 ' && echo 'Cassandra OK'"

echo "==> Kafka: broker responds to --list"
run "/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list >/dev/null && echo 'Kafka OK'"

echo "All four NoSQL services responded."
