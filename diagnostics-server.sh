#!/bin/sh

# Simple HTTP server that returns diagnostics JSON

while true; do
  {
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"

    echo "\"docker_running\": \"$(docker ps >/dev/null 2>&1 && echo yes || echo no)\","

    echo "\"containers\": {"
    for S in honeygain pawns watchtower dozzle
