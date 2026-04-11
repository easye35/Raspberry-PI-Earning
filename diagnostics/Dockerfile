# ------------------------------------------------------------
# EarnBox Backend Dockerfile
# ------------------------------------------------------------

FROM node:18-alpine

# Create app directory
WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install dependencies
RUN npm install --production

# Copy backend + dashboard
COPY server.js ./
COPY dashboard ./dashboard
COPY modules ./modules

# Expose API port
EXPOSE 3000

# Start backend
CMD ["node", "server.js"]
