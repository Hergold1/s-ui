FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm ci || npm install

COPY frontend/ ./
RUN npm run build

FROM golang:1.22-alpine AS backend-builder
WORKDIR /app

RUN apk add --no-cache gcc musl-dev git make bash curl

COPY . .

COPY --from=frontend-builder /app/frontend/dist /app/web/html

ENV CGO_ENABLED=1
RUN go build -ldflags="-w -s" \
    -tags "with_quic,with_grpc,with_utls,with_acme,with_gvisor,with_naive_outbound,with_purego" \
    -o sui main.go

FROM alpine:latest

ENV TZ=UTC
WORKDIR /app

RUN apk add --no-cache \
    bash \
    ca-certificates \
    tzdata \
    curl \
    nftables \
    iptables

COPY --from=backend-builder /app/sui /app/sui
COPY --from=backend-builder /app/bin /app/bin

RUN mkdir -p /app/db /app/cert

CMD ["./sui"]
