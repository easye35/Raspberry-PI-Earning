FROM python:3.11-slim

# Install runtime tools at build time to avoid doing this on container start
RUN apt-get update && \
    apt-get install -y --no-install-recommends sqlite3 docker.io && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workdir

# Copy a fallback snapshot into the image so the container can restore even if host file missing
# Create expected directories; actual files are mounted from the repo at runtime
RUN mkdir -p /workdir/earnings/data /workdir/scripts

# Run the self-heal script every 24 hours
CMD ["sh","-c","while true; do /workdir/scripts/self_heal.sh || true; sleep 86400; done"]
