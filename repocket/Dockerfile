FROM debian:bookworm-slim

# Install required dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Repocket
RUN bash <(curl -s https://get.repocket.co/install.sh) || \
    bash <(wget -qO- https://get.repocket.co/install.sh) || \
    echo "Repocket installation may need manual configuration"

# Create non-root user for security
RUN useradd -m -s /bin/bash repocket

# Set working directory
WORKDIR /home/repocket

# Run Repocket with provided token
ENTRYPOINT ["repocket"]
CMD ["--token", "${REPOCKET_TOKEN}"]
