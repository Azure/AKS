FROM golang:1.24 AS builder

# Install necessary build dependencies for SQLite
RUN apt-get update && apt-get install -y gcc libc6-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./
RUN CGO_ENABLED=1 GOOS=linux go build -a -installsuffix cgo -tags sqlite3 -o aks-ca-export .

FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=builder /app/aks-ca-export .
ENTRYPOINT ["./aks-ca-export"]
CMD ["-operation", "both"]