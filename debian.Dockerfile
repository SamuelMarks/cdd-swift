FROM swift:6.0-bookworm AS builder
WORKDIR /app
COPY . .
RUN swift build -c release --static-swift-stdlib

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4 libxml2 libgcc-s1 libstdc++6 zlib1g tzdata \
 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/.build/release/cdd-swift /usr/local/bin/cdd-swift
ENTRYPOINT ["cdd-swift", "serve_json_rpc", "--listen", "0.0.0.0", "--port", "8082"]