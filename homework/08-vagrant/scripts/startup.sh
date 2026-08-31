#!/usr/bin/env bash
set -euo pipefail

GO_VERSION="1.21.13"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
GO_URL="https://go.dev/dl/${GO_TARBALL}"
GO_INSTALL_DIR="/usr/local/go"
PORT="8080"
APP_DIR="/home/vagrant/calculator"

log() {
    echo "[startup] $*"
}

install_go() {
    if [[ -x "${GO_INSTALL_DIR}/bin/go" ]]; then
        log "Go already installed at ${GO_INSTALL_DIR}"
        return 0
    fi

    log "Downloading Go ${GO_VERSION}..."
    curl -fsSL "${GO_URL}" -o "/tmp/${GO_TARBALL}"
    log "Installing Go to ${GO_INSTALL_DIR}..."
    rm -rf "${GO_INSTALL_DIR}"
    tar -C /usr/local -xzf "/tmp/${GO_TARBALL}"
    rm -f "/tmp/${GO_TARBALL}"
    log "Go installed: $(${GO_INSTALL_DIR}/bin/go version)"
}

build_microservice() {
    log "Building the calculator microservice in ${APP_DIR}..."
    cd "${APP_DIR}"
    export PATH="${PATH}:${GO_INSTALL_DIR}/bin"
    export GOPATH="/home/vagrant/go"
    go build -ldflags="-s -w" -o calculator main.go
    log "Build finished: ${APP_DIR}/calculator"
}

start_microservice() {
    log "Starting calculator microservice on port ${PORT}..."
    export PATH="${PATH}:${GO_INSTALL_DIR}/bin"
    nohup "${APP_DIR}/calculator" > /tmp/calculator.log 2>&1 &
    echo $! > /tmp/calculator.pid
    sleep 1
    log "Microservice started. PID: $(cat /tmp/calculator.pid)"
}

verify() {
    log "Microservice log:"
    cat /tmp/calculator.log 2>/dev/null || true
    log "Smoke test /calc/sum/2/3:"
    curl -fsS "http://127.0.0.1:${PORT}/calc/sum/2/3" || log "Smoke test failed"
    log ""
}

main() {
    install_go
    build_microservice
    start_microservice
    verify
    log "Done."
}

main "$@"
