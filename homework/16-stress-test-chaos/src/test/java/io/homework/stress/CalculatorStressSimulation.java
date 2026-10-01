package io.homework.stress;

import static io.gatling.javaapi.core.CoreDsl.constantConcurrentUsers;
import static io.gatling.javaapi.core.CoreDsl.csv;
import static io.gatling.javaapi.core.CoreDsl.details;
import static io.gatling.javaapi.core.CoreDsl.exec;
import static io.gatling.javaapi.core.CoreDsl.global;
import static io.gatling.javaapi.core.CoreDsl.pause;
import static io.gatling.javaapi.core.CoreDsl.percent;
import static io.gatling.javaapi.core.CoreDsl.randomSwitch;
import static io.gatling.javaapi.core.CoreDsl.rampConcurrentUsers;
import static io.gatling.javaapi.core.CoreDsl.regex;
import static io.gatling.javaapi.core.CoreDsl.scenario;
import static io.gatling.javaapi.http.HttpDsl.header;
import static io.gatling.javaapi.http.HttpDsl.http;
import static io.gatling.javaapi.http.HttpDsl.status;

import io.gatling.javaapi.core.ChainBuilder;
import io.gatling.javaapi.core.ScenarioBuilder;
import io.gatling.javaapi.core.Simulation;
import io.gatling.javaapi.http.HttpProtocolBuilder;
import java.time.Duration;

/**
 * Stress test for the /calc/history endpoint of the Go calculator microservice
 * (homework/06-go/main.go).
 *
 * The endpoint answers with the whole in-memory history slice while holding a read
 * lock (main.go:82-88), and every write appends to that slice under a write lock
 * (main.go:74-76). Both facts matter for this test:
 *
 *   - the response payload grows with every write, so the read path gets heavier and
 *     heavier for the whole duration of the run;
 *   - writes and reads share one mutex, so a read-heavy workload still competes with
 *     the write path.
 *
 * The scenario therefore mixes both: WRITE_WEIGHT percent of the iterations append a
 * new operation first, so the history the reads return keeps growing.
 *
 * Everything is tunable from the command line so the same simulation can be used as a
 * 10 second smoke test or as a full stress run. Property names are also read from the
 * environment, which is what the containerised runs use.
 *
 *   mvn gatling:test -DtargetUrl=http://localhost:8080 -Dusers=100 \
 *                    -DrampSeconds=30 -DsteadySeconds=60
 *
 * See README.md for the full list of parameters and for how the run is wired into
 * Jenkins.
 */
public class CalculatorStressSimulation extends Simulation {

  /** Base URL of the microservice, e.g. http://localhost:8080 */
  private static final String TARGET_URL = setting("targetUrl", "TARGET_URL", "http://localhost:8080");

  /** Virtual users injected by the ramp phase, then held steady for the second phase. */
  private static final int USERS = intSetting("users", "USERS", 100);

  private static final int RAMP_SECONDS = intSetting("rampSeconds", "RAMP_SECONDS", 30);

  private static final int STEADY_SECONDS = intSetting("steadySeconds", "STEADY_SECONDS", 60);

  /** Think time between iterations, keeps the load from being a pure throughput race. */
  private static final int PAUSE_MILLIS = intSetting("pauseMillis", "PAUSE_MILLIS", 200);

  /** Percentage of iterations that append an operation before reading the history. */
  private static final double WRITE_WEIGHT = doubleSetting("writeWeight", "WRITE_WEIGHT", 20.0);

  /** Assertion thresholds. They gate the build: exceeding one makes Gatling exit != 0. */
  private static final double MAX_ERROR_PERCENT = doubleSetting("maxErrorPercent", "MAX_ERROR_PERCENT", 1.0);

  private static final int MAX_P95_MILLIS = intSetting("maxP95Millis", "MAX_P95_MILLIS", 2000);

  private static final int MAX_HISTORY_P95_MILLIS =
      intSetting("maxHistoryP95Millis", "MAX_HISTORY_P95_MILLIS", 2000);

  /** Guards against a green build that actually generated no load at all. */
  private static final int MIN_REQUESTS = intSetting("minRequests", "MIN_REQUESTS", 100);

  private final HttpProtocolBuilder httpProtocol =
      http.baseUrl(TARGET_URL).acceptHeader("application/json").shareConnections().disableCaching();

  /** The endpoint under test. A fresh instance answers with the literal `null`. */
  private final ChainBuilder readHistory =
      exec(
          http("Read history")
              .get("/calc/history")
              .check(status().is(200))
              .check(header("Content-Type").is("application/json"))
              .check(regex("^(null|\\[).*$")));

  /** Grows the history slice that the reads have to serialise. Values come from operations.csv. */
  private final ChainBuilder writeOperation =
      exec(
          http("Write operation")
              .get("/calc/#{op}/#{a}/#{b}")
              .check(status().is(200))
              .check(regex(".*\"result\":.*")));

  private final ScenarioBuilder scenario =
      scenario("Calculator history under load")
          // random().circular() picks a random row and recycles the file. The default csv
          // feeder is queue based: once its rows are consumed it crashes the load generator
          // and the run stalls instead of reporting anything.
          .feed(csv("operations.csv").random().circular())
          .exec(
              randomSwitch()
                  .on(
                      percent(WRITE_WEIGHT).then(writeOperation, readHistory),
                      percent(100.0 - WRITE_WEIGHT).then(readHistory)))
          // Duration, not an int: pause(int) is interpreted as *seconds* by Gatling
          .pause(Duration.ofMillis(PAUSE_MILLIS));

  {
    setUp(
            scenario
                .injectClosed(
                    rampConcurrentUsers(1).to(USERS).during(Duration.ofSeconds(RAMP_SECONDS)),
                    constantConcurrentUsers(USERS).during(Duration.ofSeconds(STEADY_SECONDS)))
                .protocols(httpProtocol))
        .maxDuration(Duration.ofSeconds(RAMP_SECONDS + STEADY_SECONDS + 30))
        .assertions(
            global().allRequests().count().gt((long) MIN_REQUESTS),
            global().failedRequests().percent().lt(MAX_ERROR_PERCENT),
            global().responseTime().percentile3().lt(MAX_P95_MILLIS),
            details("Read history").responseTime().percentile3().lt(MAX_HISTORY_P95_MILLIS));
  }

  private static String setting(String property, String envVar, String fallback) {
    String value = System.getProperty(property);
    if (value == null || value.isBlank()) {
      value = System.getenv(envVar);
    }
    return (value == null || value.isBlank()) ? fallback : value;
  }

  private static int intSetting(String property, String envVar, int fallback) {
    return Integer.parseInt(setting(property, envVar, String.valueOf(fallback)));
  }

  private static double doubleSetting(String property, String envVar, double fallback) {
    return Double.parseDouble(setting(property, envVar, String.valueOf(fallback)));
  }
}