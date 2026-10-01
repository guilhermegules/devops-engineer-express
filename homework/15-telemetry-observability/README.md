# Homework 15 - Telemetry & Observability

This homework instruments the **Go calculator microservice** (from `../06-go`) with
[collectd](https://collectd.org/) and ships its metrics and logs into the
**ELK stack** (Elasticsearch + Logstash + Kibana), following the assignment in
`15-Telemetry.Observability.txt`:

1. Change the Dockerfile of the go microservice and install collectD.
2. Run the ELK Stack and send your custom collectd metrics and logs there.

The microservice itself is untouched — the build reuses `../06-go/main.go`, exactly
like `../07-docker/Dockerfile` does. Everything added here is container, agent and
pipeline configuration.

## Architecture

```
                              +-------------------------------+
 06-go calculator  ---------> | calculator container         |
 (stdout/stderr)              |  - ./calculator   :8080       |
                              |  - collectd (10s interval)   |
                              |    custom metrics via exec   |
                              |    host metrics: cpu/mem/... |
                              +---------------+---------------+
                                              |
             /var/log/calculator/calculator.log  (shared volume)
                                              |
 +-----------------+                +--------v---------+         +------------------+
 |    collectd     | --write_http-->|     Logstash     |-------->|  Elasticsearch   |
 |  + log_logstash |  POST, JSON    |  http input      |         | calculator-*     |
 +-----------------+  array         |  file input x2   |         | indices          |
     |            |                +------------------+         +--------+---------+
     | collectd.log (log_logstash plugin, Logstash JSON)                   |
     +---------------------------------------------------------------->  |
                                                          +------------v------------+
                                                          |          Kibana         |
                                                          |  http://localhost:5601  |
                                                          +-------------------------+
```

**How the metrics travel.** `write_http` with `Format JSON` POSTs a single valid JSON
array of value lists to Logstash, and the Logstash `json` codec turns every element of
that root-level array into its own event. A `ruby` filter then flattens collectd's two
parallel arrays (`dsnames` / `values`) into `metric.values.<name>` so the series can be
charted in Kibana.

**Why not `write_log`.** In collectd 5.12 the `write_log` plugin only accepts a
`Format` option and writes through collectd's own log, so metrics would arrive mixed
with log output. `write_logstash` is not packaged for Alpine. `write_http` is both
available (`collectd-write_http`) and the correct push-based design.

**How the logs travel.** Two independent paths, both in the same pipeline:

- the microservice's `stdout`/`stderr` is appended to `calculator.log` and tailed by a
  Logstash `file` input (`plain` codec);
- collectd's own log messages are turned into Logstash-format JSON by the collectd
  `log_logstash` plugin and tailed by a second `file` input (`json` codec).

## Pipeline gotchas

These are the non-obvious constraints behind the configuration. They are easy to get
wrong and fail silently, so they are worth stating explicitly.

- **ECS compatibility is disabled** (`pipeline.ecs_compatibility: disabled` in
  `logstash/config/logstash.yml`). With Logstash 8's default `v8` mode the `http` input
  stores the client address in a `host` object (`host.ip`). collectd's own JSON also
  carries a `host` *string*, and setting a string on top of an object raises
  `InvalidFieldSetException`, so **every** collectd batch is dropped with
  `_jsonparsefailure`. The collectd schema is custom, not ECS, so disabling it is the
  honest setting.
- **The `json` codec's `target` is ignored for a root-level array.** collectd posts a
  JSON *array* of value lists and the codec turns each element into an event, so
  `codec => json { target => "collectd" }` would not namespace anything — the fields
  stay at the top level and the `ruby` filter renames them into `metric.*` itself.
- **`@timestamp` is set by the `date` filter, not by `ruby`.** The `ruby` filter cannot
  assign `@timestamp` directly (`wrong argument type Time (expected LogStash::Timestamp)`,
  and `LogStash::Timestamp.new` is not constructible from an integer here). The `ruby`
  filter converts collectd's epoch seconds into `[@metadata][collected_at_ms]` and the
  `date` filter matches `UNIX_MS` onto `@timestamp`, which keeps the sub-second
  precision collectd reports.
- **The `exec` plugin refuses to run as root** (`exec plugin: Cowardly refusing to exec
  program as root.`), so `collectd.conf` runs the metrics script as `nobody`. Without
  this the custom metrics are never collected and the only symptom is a log line.
- **`write_http`'s `Timeout` is in milliseconds** (it maps to `CURLOPT_TIMEOUT_MS`), so
  the natural-looking `Timeout 5` is a 5 ms budget and every flush fails with
  `curl_easy_perform failed with status 28`. The option is left unset so the default
  (no limit) applies.
- **The `interface` plugin's `Interface` is a *select* list.** With its default
  `IgnoreSelected false`, naming an interface makes collectd report *only* that device.
  `Interface "lo"` plus `IgnoreSelected true` is what actually drops loopback and keeps
  `eth0`.
- **The log files must not be truncated on start.** `entrypoint.sh` only `touch`es them.
  Truncating a file that a Logstash `file` input is tailing invalidates the position in
  its sincedb database, and the new lines are then skipped. Use
  `./manage-telemetry.sh clean` to start over.
- **`host` holds the shipping container's address**, not collectd's `hostname`, because
  the `http` input's own `host` overwrites collectd's value. It is copied to
  `metric.host` so every metric document has a consistent series host; the producer is
  identified by `headers.http_user_agent` (`collectd/5.12.0.git`).

If a previous run created an Elasticsearch mapping before one of these was fixed, the
index can keep a conflicting type. `object mapping for [host] tried to parse field [host]
as object` is the symptom; delete the affected index and let Logstash recreate it.

## Files

| File | Description |
|---|---|
| `Dockerfile` | Builds the go microservice, then adds collectd + the exec/write_http/log_logstash plugins on `alpine:3.20` |
| `collectd.conf` | collectd config: read plugins, the `exec` custom-metrics bridge, `write_http` to Logstash, `log_logstash` to a file |
| `calculator-metrics.sh` | Runs every 10s under the `exec` plugin; reads `/calc/history` and emits one `PUTVAL` per metric |
| `entrypoint.sh` | Container entrypoint: starts the microservice and collectd, and winds both down if either exits |
| `docker-compose.yml` | Elasticsearch, Logstash, Kibana and the instrumented microservice |
| `logstash/config/logstash.yml` | Logstash settings (monitoring off, single pipeline worker) |
| `logstash/pipeline/logstash.conf` | Three inputs, the collectd value-list flattener, and the Elasticsearch output |
| `manage-telemetry.sh` | `up` / `down` / `status` / `restart` / `logs` / `ps` / `clean` / `help` |
| `send-requests.sh` | Generates calculator traffic so there is something to observe |
| `verify-telemetry.sh` | Asserts that metrics and logs really reached Elasticsearch |
| `15-Telemetry.Observability.txt` | The homework assignment statement |

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and the Compose plugin
- ~4 GB of free RAM: Elasticsearch is capped with `ES_JAVA_OPTS=-Xms1g -Xmx1g`,
  Logstash with `LS_JAVA_OPTS=-Xms512m -Xmx512m`
- Free host ports: `8080` (microservice), `9200` (Elasticsearch), `9600` (Logstash
  ingest endpoint), `5601` (Kibana)
- Outbound access to `alpine`, `golang` and `docker.elastic.co` to pull the images

## Custom metrics

`calculator-metrics.sh` derives application-level metrics from the microservice's own
`/calc/history` endpoint, so they describe the service rather than the host:

| Metric (`type_instance`) | Meaning |
|---|---|
| `app_reachable` | `1` when `/calc/history` answered, `0` otherwise |
| `operations_total` | Number of operations performed since start |
| `operations_sum` / `_sub` / `_mul` / `_div` | Operations broken down per operation |
| `last_result` | Result of the most recent operation |
| `history_bytes` | Size of the history payload, a proxy for unbounded growth |

Each one is a `gauge` with `plugin=exec` and `plugin_instance=calculator`, and arrives
in Elasticsearch as `metric.name` such as `exec.calculator.gauge.app_reachable`.

Alongside those, collectd reports the usual `cpu`, `memory`, `load`, `uptime` and
`interface` series for the container.

## Usage

### 1. Start everything

```bash
./manage-telemetry.sh up
```

This builds the microservice image, starts the four containers, and waits for
Elasticsearch to report healthy.

### 2. Generate traffic and verify

```bash
./send-requests.sh 20
sleep 15          # let collectd run one interval and Logstash flush
./verify-telemetry.sh
```

`verify-telemetry.sh` checks the cluster health, the microservice, the document counts
of all three indices, that the custom `exec` metrics (including `app_reachable`) are
indexed, that the `cpu`/`memory`/`load`/`uptime` host series and the `eth0` interface
series are present, that loopback is excluded, and that no document was indexed with a
`_rubyexception` or `_jsonparsefailure` tag. It exits non-zero if any check fails.

### 3. Explore in Kibana

Open <http://localhost:5601> and create a data view for `calculator-metrics-*`, then
add `metric.values.value` (or `metric.values.rx` for network) as a metric, split by
`metric.name`, and filter on `metric.source: exec` to see only the custom metrics.

`calculator-app-logs-*` and `calculator-collectd-logs-*` are meant to be read in
**Discover**.

### Script reference

#### `manage-telemetry.sh`

```bash
./manage-telemetry.sh {up|down|status|restart|logs|ps|clean|help}
```

- `up` — build and start the stack, then wait for Elasticsearch
- `down` — remove the containers, keeping the volumes (so the data survives)
- `status` — container state plus the Elasticsearch cluster health
- `logs [SERVICE...]` — follow logs, e.g. `./manage-telemetry.sh logs calculator`
- `clean` — remove containers, networks, volumes **and** the built image

#### `send-requests.sh`

```bash
./send-requests.sh [REQUESTS]   # default: 20
```

Cycles through the four operations and prints the resulting history.

#### `verify-telemetry.sh`

```bash
./verify-telemetry.sh
```

Environment: `ES_URL` (default `http://localhost:9200`) and `APP_URL`
(default `http://localhost:8080`).

## Indices

| Index pattern | Content | Key fields |
|---|---|---|
| `calculator-metrics-*` | One document per collectd value list | `metric.name`, `metric.source`, `metric.instance`, `metric.host`, `metric.values.*`, `host`, `interval` |
| `calculator-app-logs-*` | Microservice stdout/stderr | `message` |
| `calculator-collectd-logs-*` | collectd log messages | `message`, `level` |

## Troubleshooting

- **`calculator-metrics-*` is empty**: collectd runs on a 10s `Interval`, and
  `write_http` only flushes once per read cycle, so wait ~15s after starting the
  container. Then check `./manage-telemetry.sh logs calculator` for
  `write_http: HTTP Error code` — that means Logstash was not reachable yet.
- **No data but no errors**: confirm collectd is running with
  `docker compose -f docker-compose.yml exec calculator ps -o pid,comm` and that
  `container_name` for the logstash service is `calculator-logstash`, since
  `collectd.conf` posts to the fixed URL `http://logstash:8080/`.
- **Exec metrics stuck at `app_reachable 0`**: the exec script could not reach
  `http://127.0.0.1:8080/calc/history` inside the container. Check the microservice
  logs. The zeros are intentional, so the gap is visible as a flat series.
- **Elasticsearch container restarts**: it needs about 1 GB of heap plus overhead.
  Lower `ES_JAVA_OPTS` or free host memory.
- **`calculator-collectd-logs-*` is empty**: `log_logstash` is configured with
  `LogLevel "info"`, so a healthy collectd simply has little to say. The index fills up
  when something goes wrong.
- **Port already in use**: change the left-hand side of the mapping in
  `docker-compose.yml` (e.g. `"9201:9200"`), and for Logstash remember that
  `collectd.conf` posts to port `8080` *inside* the network.
- **Re-indexing the logs after a `down`**: `logstash-data` holds the `file` input
  sincedb, so lines are not indexed twice. If you delete that volume, the files are
  re-read from the beginning.

## Notes

- The build context is the **repository root**, matching the working Packer template
  in `../12-jenkins/packer/calculator.pkr.hcl` (`build_dir = "${path.root}/../../.."`)
  and the `COPY homework/06-go/...` lines of `../07-docker/Dockerfile`.
- `../07-docker/manage-calculator.sh` sets `BUILD_CONTEXT` to the `homework/` directory
  while its Dockerfile copies `homework/06-go/...`, so those paths only resolve from
  the repository root. That script is left untouched here.
