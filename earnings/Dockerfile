FROM python:3.11-slim

WORKDIR /app

# Install system dependencies (sqlite3, curl, etc.)
RUN apt-get update && \
    apt-get install -y sqlite3 curl && \
    apt-get clean

# Copy requirements first (better caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install Docker SDK so backend can read container logs
RUN pip install docker

# Copy the rest of the earnings app
COPY . .

# Expose API port
EXPOSE 5000

# Run the earnings aggregator
CMD ["python", "-m", "app"]
