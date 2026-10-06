# 16 - Stress Test / Gatling

Gatling load test for the calculator microservice from homework 06, plus a self contained
Jenkins controller that runs the test and publishes the HTML report.

The homework asks for a stress test of `/history`. The service actually exposes
`GET /calc/history` (`homework/06-go/main.go`), so that is what the simulation hits.

## Layout

| Path | Purpose |
| --- | --- |
| `pom.xml` | Gatling 3.16.0 project, Maven based |
| `src/test/java/io/homework/stress/CalculatorStressSimulation.java` | The simulation |
| `src/test/resources/operations.csv` | Feed of calculator operations for the write path |
| `run-stress-test.sh` | Local runner, same parameters as the pipeline |
| `manage-calculator.sh` | Starts/stops the Go service under test in Docker |
| `Jenkinsfile` | Pipeline: `WAIT FOR APP` -> `STRESS TEST` -> `PUBLISH REPORT` |
| `jenkins/` | Controller image, plugins and the groovy that seeds the job |
| `docker-compose.yml` | Starts the controller on port 8283 |

## Running locally

`run-stress-test.sh` starts the calculator for you when nothing answers on port 8080, so a
single command is enough:

```bash
./run-stress-test.sh                                     # defaults: 100 users, 30s ramp, 60s steady
./run-stress-test.sh http://localhost:8080 25 10 30      # 25 users, 10s ramp, 30s steady
```

Arguments are `BASE_URL USERS RAMP_SECONDS STEADY_SECONDS`. The service can also be managed
on its own, which is handy when you want to watch it while the test runs:

```bash
./manage-calculator.sh up        # build from homework/07-docker/Dockerfile and start on 8080
./manage-calculator.sh status    # container state plus a readiness probe
./manage-calculator.sh logs      # follow the container logs
./manage-calculator.sh restart   # wipes the in memory history, so p95 stays comparable
./manage-calculator.sh down
```

It publishes port 8080 and names the container `calculator-stress-test`, which keeps it from
colliding with the `calculator-microservice` container of homework 07. The image is built
from `homework/06-go` with the repo root as build context, and the container is attached to
its own bridge network `calculator-stress-test-net` rather than the default one.

If port 8080 is already taken, `up` gives up on it, says who is holding it, and moves to the
next free port. The port it settled on is printed on a `Calculator base URL:` line and kept in
`.manage-calculator.state`, so `status`, `logs` and `down` follow it:

```bash
./manage-calculator.sh up
# Port 8080 is busy (held by container: calculator-telemetry), falling back to 8081.
# Calculator base URL: http://localhost:8081
```

`run-stress-test.sh` reads that same line, so an auto-started service on a fallback port is
still tested correctly. Pin the port yourself with `PORT=8081` if you prefer.

`mvn` exits non zero when an assertion is breached, so the script doubles as a CI gate. The
report lands in `target/gatling/<simulation>/index.html`.

## Starting everything from scratch

```bash
# 1. the service under test (optional, run-stress-test.sh starts it too)
./manage-calculator.sh up

# 2. the load test
./run-stress-test.sh

# 3. the Jenkins controller
docker compose up -d
docker compose logs -f jenkins    # wait for "Jenkins is fully up and running"

# 4. teardown
./manage-calculator.sh down
docker compose down
```

Requires Docker, `curl` and Maven for the local run. The first `up` builds the image, the
first Jenkins build downloads the Gatling dependencies into the `jenkins_home` volume.

## Checking the Jenkins process

The controller listens on 8283 and needs about a minute to become ready, so poll instead of
assuming:

```bash
docker ps --filter name=jenkins-stress-test     # expect: Up ... 0.0.0.0:8283->8080/tcp
docker logs jenkins-stress-test 2>&1 | grep "Jenkins is fully up and running"
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8283/login   # expect: 200
curl -s -u admin:admin http://localhost:8283/api/json >/dev/null && echo "credentials ok"
```

`docker compose ps` and `docker compose logs jenkins` do the same from the compose side.

Run a build from the UI: open <http://localhost:8283> (`admin` / `admin`), job
`calculator-stress-test`, **Build Now**, then follow the console
(<http://localhost:8283/job/calculator-stress-test/console>). To check it from the shell:

```bash
# trigger (plain /build: the seeded job has no declared parameters yet)
curl -u admin:admin -X POST http://localhost:8283/job/calculator-stress-test/build

# last result: color blue = success, red = failure. The brackets must be %5B/%5D
curl -s -u admin:admin \
  'http://localhost:8283/job/calculator-stress-test/api/json?tree=color,lastBuild%5Bnumber,building,result%5D'

# console log of the last build
curl -s -u admin:admin http://localhost:8283/job/calculator-stress-test/lastBuild/consoleText | tail -40

# is the published report reachable?
curl -s -o /dev/null -w '%{http_code}\n' -u admin:admin \
  http://localhost:8283/job/calculator-stress-test/lastBuild/Gatling_20Report/
```

A successful build ends with `BUILD SUCCESS` from Maven, then
`[htmlpublisher] Archiving at BUILD level ...`, and the last line reads
`Stress test passed: the microservice met every assertion.`

## Running in Jenkins

The controller reaches the microservice through `host.docker.internal` because the service
runs on the Docker host, not inside the Jenkins network. Override `APP_URL` if your service
lives somewhere else. The pipeline's `WAIT FOR APP` stage gives up after 60s and fails the
build, so a missing service is reported as such instead of as a Gatling error.

The job is created by `jenkins/init.groovy.d/01-setup-security-and-seed.groovy`, which reads
`Jenkinsfile` out of the workspace copy of the repository on every controller start. Restart
the container after editing the pipeline, or re run `docker compose down -v && docker compose
up -d` to start from a clean `JENKINS_HOME`.

## Parameters

Both the pipeline and the simulation read the same settings, from system properties or the
environment.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `APP_URL` / `targetUrl` | `http://host.docker.internal:8080` | Base URL of the service |
| `USERS` / `users` | `100` | Concurrent users held during the steady phase |
| `RAMP_SECONDS` / `rampSeconds` | `30` | Seconds spent ramping up to `USERS` |
| `STEADY_SECONDS` / `steadySeconds` | `60` | Seconds held at `USERS` |
| `MAX_ERROR_PERCENT` / `maxErrorPercent` | `1.0` | Assertion: share of failed requests |
| `MAX_P95_MILLIS` / `maxP95Millis` | `2000` | Assertion: global 95th percentile in ms |
| `maxHistoryP95Millis` | `2000` | Assertion: 95th percentile of `/calc/history` reads |
| `minRequests` | `100` | Assertion: total request count, guards a no-op run |
| `writeWeight` | `20` | Percent of requests that write before reading history |
| `pauseMillis` | `200` | Think time between requests |

## What the simulation does

Every virtual user runs the same loop: 80% of the time it reads `/calc/history`, 20% of the
time it performs a random addition or multiplication from `operations.csv` and then reads
history. Writes go through a shared circular feeder, so the operation mix stays stable no
matter how long the run lasts.

Assertions are written so that they fail the build when the service misbehaves:

* at least `minRequests` requests were issued,
* fewer than `maxErrorPercent` percent failed,
* global p95 under `maxP95Millis`,
* `/calc/history` p95 under `maxHistoryP95Millis`.

## Results on this machine

100 users, 30s ramp, 60s steady, on an empty history, `./run-stress-test.sh`:

```
requests      9,565    failures  0    mean throughput  19.6 rps
p95           595 ms   /calc/history p95  477 ms   max 383,035 ms
```

Same profile through Jenkins (build #1, ~9m48s wall clock):

```
requests      17,560   failures  0    mean throughput  170.5 rps
p95           1,046 ms /calc/history p95  195 ms
```

The two numbers are not comparable to each other: the local run above hit the long lived
homework 15 container, whose history already held tens of thousands of entries, so every
`/calc/history` response was megabytes wide. `./manage-calculator.sh restart` empties the
history and brings the same numbers down by an order of magnitude.

Throughput drops as the test goes on because the service keeps every calculation in memory
and `/calc/history` serialises the whole list: after ~20k writes the response is over 1 MB,
and p95 lands close to the 2,000 ms assertion. `./manage-calculator.sh restart` between runs
if you want comparable numbers.

## Gotchas found while building this

* `pause(200)` in the Java DSL means 200 **seconds**, not 200 ms. The simulation uses
  `pause(Duration.ofMillis(...))`.
* Gatling's CSV `.random()` and `.shuffle()` feeders are queue based and fail once the data
  runs out. `.random().circular()` recycles the rows, which is what a long running test
  needs.
* `timestamps()` in the pipeline needs the `timestamper` plugin, which `workflow-aggregator`
  does not pull in.
* Reports of earlier runs used to be archived together with the current one, since the
  pipeline picked the alphabetically last directory under `target/gatling`. It now deletes
  `target/gatling` before the run and selects the newest `index.html`.
* A container on the **default bridge** network is not reliably reachable from the host here:
  `-p 8081:8081` listened but returned an empty reply. The same image on a user defined
  bridge published fine, so `manage-calculator.sh` creates
  `calculator-stress-test-net` and attaches the container to it.
* `curl http://localhost:PORT` resolves `::1` first, and this host's IPv6 docker port mapping
  resets those connections instead of refusing them, so curl exits 56 without falling back to
  IPv4. Both scripts probe with `--ipv4`.
* `homework/06-go/main.go` hardcodes `ListenAndServe(":8080")`, so only the host side of the
  mapping can move: `-p "${PORT}:8080"`.