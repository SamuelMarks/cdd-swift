FROM swift:6.0-bookworm AS builder
WORKDIR /app
COPY . .
RUN swift build -c release --static-swift-stdlib

FROM alpine:latest
RUN apk add --no-cache gcompat libstdc++ tzdata curl zlib libxml2 musl-fts
COPY --from=builder /app/.build/release/cdd-swift /usr/local/bin/cdd-swift
ENV LD_PRELOAD=/usr/lib/libfts.so.0
ENTRYPOINT ["cdd-swift", "serve_json_rpc", "--listen", "0.0.0.0", "--port", "8082"]