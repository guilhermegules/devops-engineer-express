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
| `Jenkinsfile` | Pipeline: `WAIT FOR APP` -> `STRESS TEST` -> `PUBLISH REPORT` |
| `jenkins/` | Controller image, plugins and the groovy that seeds the job |
| `docker-compose.yml` | Starts the controller on port 8283 |

## Running locally

The microservice must be up first (`homework/07-docker/manage-calculator.sh start`, or the
container from homework 11).

```bash
./run-stress-test.sh                        # defaults: 100 users, 30s ramp, 60s steady
./run-stress-test.sh 25 10 30              # 25 users, 10s ramp, 30s steady
./run-stress-test.sh 10 5 15 http://localhost:8080
```

`mvn` exits non zero when an assertion is breached, so the script doubles as a CI gate. The
report lands in `target/gatling/<simulation>/index.html`.

## Running in Jenkins

```bash
docker compose up -d
docker compose logs -f jenkins     # wait for "Jenkins is fully up and running"
```

Then open <http://localhost:8283> (`admin` / `admin`), build job `calculator-stress-test`,
and read the report from the **Gatling Report** link on the build page.

The controller reaches the microservice through `host.docker.internal` because the service
runs on the Docker host, not inside the Jenkins network. Override `APP_URL` if your service
lives somewhere else.

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

100 users, 30s ramp, 60s steady, against the homework 06 service on an empty history:

```
requests      38,950    failures  0    mean throughput  428 rps
p95           89 ms    /calc/history p95  45 ms
```

Throughput drops as the test goes on because the service keeps every calculation in memory
and `/calc/history` serialises the whole list: after ~20k writes the response is over 1 MB,
and p95 lands close to the 2,000 ms assertion. Restart the service between runs if you want
comparable numbers.

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