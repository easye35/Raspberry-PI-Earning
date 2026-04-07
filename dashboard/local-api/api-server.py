#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import subprocess
import json

API_SCRIPT = "/home/easye35/Raspberry-PI-docker-Earning/dashboard/local-api/api.sh"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/api.json":
            self.send_response(404)
            self.end_headers()
            return

        try:
            # Run the existing api.sh script
            output = subprocess.check_output(
                [API_SCRIPT],
                stderr=subprocess.STDOUT
            ).decode().strip()

            # Validate JSON
            data = json.loads(output)

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode())

        except Exception as e:
            # Return a safe fallback JSON
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({
                "error": str(e),
                "hdd_temp": "",
                "hdd_health": "",
                "cpu_temp": "",
                "uptime": "",
                "load": "",
                "power": ""
            }).encode())

server = HTTPServer(("0.0.0.0", 8080), Handler)
server.serve_forever()
