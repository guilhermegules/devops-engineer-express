package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
)

type Operation struct {
	Op        string  `json:"op"`
	A         float64 `json:"a"`
	B         float64 `json:"b"`
	Result    float64 `json:"result"`
	Timestamp string  `json:"timestamp"`
}

var (
	history []Operation
	mu      sync.RWMutex
)

func calcHandler(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/calc/")
	parts := strings.Split(path, "/")

	if len(parts) < 3 {
		http.Error(w, "invalid URL format. Use: /calc/<op>/<a>/<b>", http.StatusBadRequest)
		return
	}

	op := parts[0]
	a, err := strconv.ParseFloat(parts[1], 64)
	if err != nil {
		http.Error(w, "invalid number for a", http.StatusBadRequest)
		return
	}
	b, err := strconv.ParseFloat(parts[2], 64)
	if err != nil {
		http.Error(w, "invalid number for b", http.StatusBadRequest)
		return
	}

	var result float64
	switch op {
	case "sum":
		result = a + b
	case "sub":
		result = a - b
	case "mul":
		result = a * b
	case "div":
		if b == 0 {
			http.Error(w, "division by zero", http.StatusBadRequest)
			return
		}
		result = a / b
	default:
		http.Error(w, "unknown operation. Use: sum, sub, mul, div", http.StatusBadRequest)
		return
	}

	operation := Operation{
		Op:        op,
		A:         a,
		B:         b,
		Result:    result,
		Timestamp: time.Now().Format(time.RFC3339),
	}

	mu.Lock()
	history = append(history, operation)
	mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(operation)
}

func historyHandler(w http.ResponseWriter, r *http.Request) {
	mu.RLock()
	defer mu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(history)
}

func main() {
	http.HandleFunc("/calc/", calcHandler)
	http.HandleFunc("/calc/history", historyHandler)

	fmt.Println("Calculator microservice running on http://0.0.0.0:8080")
	http.ListenAndServe(":8080", nil)
}
