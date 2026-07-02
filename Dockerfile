# ---- build stage --------------------------------------------------------
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Download dependencies separately so this layer is cached unless go.mod changes.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w -X main.version=${VERSION}" \
    -o /app/bin/server \
    ./cmd/server

# ---- runtime stage ------------------------------------------------------
FROM scratch

# TLS root certs (needed for outbound HTTPS calls).
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=builder /app/bin/server /server

EXPOSE 8080

# Run as a non-root UID.
USER 65534:65534

ENTRYPOINT ["/server"]
