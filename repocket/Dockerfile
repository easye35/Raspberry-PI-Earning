FROM debian:bookworm-slim

# Install required dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and install Repocket CLI
RUN mkdir -p /opt/repocket && \
    cd /opt/repocket && \
    wget -q https://downloads.repocket.co/repocket-linux-arm64 -O repocket || \
    wget -q https://downloads.repocket.co/repocket-linux-armv7 -O repocket || \
    echo "Note: Repocket CLI may need to be pre-downloaded" && \
    chmod +x /opt/repocket/repocket || true

# Add to PATH
ENV PATH="/opt/repocket:${PATH}"

# Create non-root user for security
RUN useradd -m -s /bin/bash repocket

# Set working directory
WORKDIR /home/repocket

# Run Repocket with provided token
CMD ["sh", "-c", "repocket --token ${REPOCKET_TOKEN} || echo 'Repocket CLI not found. Please ensure it is installed or pre-built.'"]
