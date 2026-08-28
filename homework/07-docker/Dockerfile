FROM golang:1.21-alpine AS build

WORKDIR /app

COPY homework/06-go/go.mod ./
COPY homework/06-go/main.go ./

RUN go build -o calculator main.go

FROM alpine:latest

WORKDIR /app

COPY --from=build /app/calculator .

EXPOSE 8080

CMD ["./calculator"]
