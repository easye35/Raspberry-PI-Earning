FROM node:18-slim

WORKDIR /app/backend

RUN apt-get update && \
    apt-get install -y python3 make g++ sqlite3 libsqlite3-dev && \
    apt-get clean

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3001

CMD ["node", "server.js"]
