FROM node:18-alpine

WORKDIR /app

# Copy backend and install dependencies
COPY backend ./backend
RUN cd backend && npm install && npm install dockerode node-fetch@2

# Copy dashboard frontend
COPY dashboard ./dashboard

# Expose HTTP port
EXPOSE 80

# Start backend + frontend
CMD node backend/server.js & \
    npx http-server dashboard -p 80 -c-1
