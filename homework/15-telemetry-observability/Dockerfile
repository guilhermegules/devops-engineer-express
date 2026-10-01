FROM golang:1.21-alpine AS build

WORKDIR /app

COPY homework/06-go/go.mod ./
COPY homework/06-go/main.go ./

RUN go build -o calculator main.go

FROM alpine:3.20

RUN apk add --no-cache \
      collectd \
      collectd-exec \
      collectd-write_http \
      collectd-log_logstash \
      curl

WORKDIR /app

COPY --from=build /app/calculator .
COPY homework/15-telemetry-observability/collectd.conf /etc/collectd.conf
COPY homework/15-telemetry-observability/calculator-metrics.sh /usr/local/bin/calculator-metrics.sh
COPY homework/15-telemetry-observability/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 0755 /usr/local/bin/calculator-metrics.sh /usr/local/bin/entrypoint.sh

ENV LOG_DIR=/var/log/calculator
ENV LOGSTASH_URL=http://logstash:8080/

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
