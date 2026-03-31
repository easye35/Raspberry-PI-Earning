package main
import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/client"
	"golang.org/x/net/context"
)

import "regexp"

var ansi = regexp.MustCompile(`\x1b\[[0-9;]*[a-zA-Z]`)

func stripANSI(input string) string {
    return ansi.ReplaceAllString(input, "")
}

func enableCORS(w http.ResponseWriter) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
}

func containersHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(w)

	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	containers, err := cli.ContainerList(context.Background(), container.ListOptions{
		All: true,
	})
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	json.NewEncoder(w).Encode(containers)
}

func logsHandler(w http.ResponseWriter, r *http.Request) {
    enableCORS(w)

    name := r.URL.Query().Get("container")
    if name == "" {
        http.Error(w, "missing container parameter", 400)
        return
    }

    cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
    if err != nil {
        http.Error(w, err.Error(), 500)
        return
    }

    reader, err := cli.ContainerLogs(context.Background(), name, container.LogsOptions{
        ShowStdout: r.URL.Query().Get("stdout") == "true",
        ShowStderr: r.URL.Query().Get("stderr") == "true",
        Tail:       r.URL.Query().Get("tail"),
    })
    if err != nil {
        http.Error(w, err.Error(), 500)
        return
    }
    defer reader.Close()

    // Read all logs
    raw, err := io.ReadAll(reader)
    if err != nil {
        http.Error(w, err.Error(), 500)
        return
    }

    // Strip ANSI codes
    clean := stripANSI(string(raw))

    w.Write([]byte(clean))
}

func main() {
	http.HandleFunc("/api/v1/containers", containersHandler)
	http.HandleFunc("/api/v1/logs", logsHandler)

	port := "9999"
	fmt.Println("Backend API running on port", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
