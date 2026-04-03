import subprocess
import json

def get_containers():
    try:
        result = subprocess.check_output(
            ["docker", "ps", "--format", "{{json .}}"],
            text=True
        ).strip().split("\n")

        containers = [json.loads(line) for line in result if line]
        return containers

    except Exception:
        return []


def get_container_stats():
    try:
        result = subprocess.check_output(
            [
                "docker", "stats", "--no-stream",
                "--format", "{{json .}}"
            ],
            text=True
        ).strip().split("\n")

        stats = [json.loads(line) for line in result if line]
        return stats

    except Exception:
        return []
