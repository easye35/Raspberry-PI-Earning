FROM golang:1.25-alpine AS build
WORKDIR /app

RUN apk add --no-cache git

COPY . .

RUN go mod tidy
RUN go mod download

RUN go build -o backend .

FROM alpine:latest
WORKDIR /app
COPY --from=build /app/backend .
CMD ["./backend"]
